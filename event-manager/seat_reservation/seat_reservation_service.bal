import ballerina/mb;
import ballerina/http;
import ballerina/internal;
import ballerina/log;
import ballerina/config;

endpoint mb:SimpleQueueReceiver invitationAcknowledgeQueueReceiver {
    host: "localhost",
    port: 5672,
    queueName: "InvitationAcknowledgeQueue"
};

endpoint http:Client eventDbServiceEndpoint {
    url: "http://localhost:9091/event"
};

service<mb:Consumer> seatReservationListener bind invitationAcknowledgeQueueReceiver {
    onMessage (endpoint consumer, mb:Message mbMessage) {
        string textPayload = check mbMessage.getTextMessageContent();
        int noOfSeats = config:getAsInt("event_manager.seats");
        json jsonPayload =  stringToBoolean(textPayload);
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
                            sendRequest(requestType, jsonPayload, errMsg);
                            //send email
                        } else {
                            log:printDebug("Seats not available for reservation");
                            //send email no seats
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
            sendRequest(requestType, jsonPayload, errMsg);
            //send email no seats
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

function sendRequest(string requestType, json jsonPayload, string errMsg) {
    if (requestType == "new") {
        sendInsertOrUpdateRequest(jsonPayload, "POST", errMsg);
    } else if (requestType == "update") {
        sendInsertOrUpdateRequest(jsonPayload, "PUT", errMsg);
    } else {
        log:printError("Invalid invitation request type found. Type should be 'new' or 'update', found " + requestType);
        done;
    }
}

function sendInsertOrUpdateRequest(json jsonPayload, string method, string errMsg) {
    http:Request userRequest = new;
    userRequest.setJsonPayload(jsonPayload, contentType = "application/json");
    var UserResponse = eventDbServiceEndpoint->execute(method, "/users", userRequest);
    
    match UserResponse {
        http:Response resp => {    
            json responsePayload = check resp.getJsonPayload();
            if (resp.statusCode == 200 && <int>responsePayload.code == 200) {
                log:printDebug("Successfully inserted or updated");
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
}
