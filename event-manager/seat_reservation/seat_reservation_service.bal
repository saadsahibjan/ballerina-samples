import ballerina/mb;
import ballerina/http;
import ballerina/internal;
import ballerina/log;
import ballerina/config;
import wso2/gmail;

endpoint mb:SimpleQueueReceiver invitationAcknowledgeQueueReceiver {
    host: "localhost",
    port: 5672,
    queueName: "InvitationAcknowledgeQueue"
};

endpoint http:Client eventDbServiceEndpoint {
    url: "http://localhost:9091/event"
};

endpoint gmail:Client gmailClient {
    clientConfig: {
        auth: {
            accessToken: config:getAsString("event_mail.ACCESS_TOKEN"),
            refreshToken: config:getAsString("event_mail.REFRESH_TOKEN"),
            clientId: config:getAsString("event_mail.CLIENT_ID"),
            clientSecret: config:getAsString("event_mail.CLIENT_SECRET")
        }
    }
};


service<mb:Consumer> seatReservationListener bind invitationAcknowledgeQueueReceiver {
    onMessage (endpoint consumer, mb:Message mbMessage) {
        string textPayload = check mbMessage.getTextMessageContent();
        int noOfSeats = config:getAsInt("event_manager.seats");
        json jsonPayload =  stringToBoolean(textPayload);
        string userEmail = check <string>jsonPayload.email;
        string userName = check <string>jsonPayload.name;
        string requestType = check <string>jsonPayload["type"];
        string errMsg = "Error occurred while processing the request ";
        if (<boolean>jsonPayload.response == true) { 
            log:printDebug("Invitation Response: Yes");
            var userAcceptCountResp = eventDbServiceEndpoint->get("/users/accept-count");
            match userAcceptCountResp {
                http:Response resp => {

                    json responsePayload = check resp.getJsonPayload();

                    if (resp.statusCode == 200 && <int>responsePayload.code == 200) {
                        int seatCount = check <int>responsePayload.records;
                        if (seatCount < noOfSeats) {
                            log:printDebug("Seats available for reservation");
                            if (sendRequest(requestType, jsonPayload, errMsg)) {
                                string emailMessage = "A seat has been reserved for you.";
                                sendEmail(userEmail, getEmailTemplate(userName, emailMessage));
                            }
                        } else {
                            log:printDebug("Seats not available for reservation");
                            string emailMessage = "Seats not available for reservation. Sorry for the inconvenience!";
                            sendEmail(userEmail, getEmailTemplate(userName, emailMessage));
                        }
                    } else {
                        log:printError(errMsg + responsePayload.toString());
                        done;
                    }
                }
                error e => {
                    log:printError(errMsg, err = e);
                    done;
                }
            }
        } else {
            log:printDebug("Invitation Response: No");
            if (sendRequest(requestType, jsonPayload, errMsg)) {
                string emailMessage = "No seat has been reserverd for you.";
                sendEmail(userEmail, getEmailTemplate(userName, emailMessage));
            }
        }
    }
}

function stringToBoolean(string textPayload) returns (json) {
    json jsonPayload = check internal:parseJson(textPayload);
    string responseValue = check <string>jsonPayload.response;
    if (responseValue == "yes") {
        jsonPayload.response = true;
    } else if (responseValue == "no") {
        jsonPayload.response = false;
    } else {
        log:printError("Invalid invitation response found. Response should be 'yes' or 'no', found " + responseValue);
        done;
    }
    return jsonPayload;
}

function sendRequest(string requestType, json jsonPayload, string errMsg) returns (boolean) {
    if (requestType == "new") {
        return sendInsertOrUpdateRequest(jsonPayload, "POST", errMsg);
    } else if (requestType == "update") {
        return sendInsertOrUpdateRequest(jsonPayload, "PUT", errMsg);
    } else {
        log:printError("Invalid invitation request type found. Type should be 'new' or 'update', found " + requestType);
        return false;
    }
}

function sendInsertOrUpdateRequest(json jsonPayload, string method, string errMsg) returns (boolean) {
    http:Request userRequest = new;
    userRequest.setJsonPayload(jsonPayload, contentType = "application/json");
    var UserResponse = eventDbServiceEndpoint->execute(method, "/users", userRequest);
    
    match UserResponse {
        http:Response resp => {    
            json responsePayload = check resp.getJsonPayload();
            if (resp.statusCode == 200 && <int>responsePayload.code == 200) {
                log:printDebug("Successfully inserted or updated");
                return true;
            } else {
                log:printError(errMsg + responsePayload.toString());
                return false;
            }
        }
        error e => {
            log:printError(errMsg, err = e);
            return false;
        }
    } 
}

function getEmailTemplate(string userName, string message) returns (string) {
    string emailTemplate = "<p> Hi " + userName + ", </p>";
    emailTemplate = emailTemplate + "<p> Thanks for your response! </p>";
    emailTemplate = emailTemplate + "<p> " + message + " </p>";
    emailTemplate = emailTemplate + "<p> Regards, <br/> Event Management Team </p>";
    return emailTemplate;
}

function sendEmail(string userEmail, string messageBody) {
    gmail:MessageRequest messageRequest;
    messageRequest.recipient = userEmail;
    messageRequest.sender = config:getAsString("event_mail.SENDER");
    messageRequest.subject = "Confirmation on Event Reservation";
    messageRequest.messageBody = messageBody;
    messageRequest.contentType = gmail:TEXT_HTML;

    var mailResponse = gmailClient->sendMessage(config:getAsString("event_mail.USER_ID"), messageRequest); 
    match mailResponse {
        (string, string) mailStatus => {
            string messageId;
            string threadId;
            (messageId, threadId) = mailStatus;
            log:printDebug("Email sent to " + userEmail + " with message ID: " + messageId + " and thread ID: " + threadId);
        }
        gmail:GmailError e => {
            log:printError(e.message, err = e);
        }
    }
}
