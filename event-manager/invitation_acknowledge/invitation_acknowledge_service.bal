import ballerina/mb;
import ballerina/http;
import ballerina/log;

endpoint mb:SimpleQueueSender invitationAcknowledgeQueueSender {
    host: "localhost",
    port: 5672,
    queueName: "InvitationAcknowledgeQueue"
};

endpoint http:Listener invitationAcknowledgeEndpoint {
    port: 9090
};


@http:ServiceConfig {
    basePath: "/invitation"
}
service<http:Service> invitationAcknowledgeService bind invitationAcknowledgeEndpoint {
    @http:ResourceConfig {
        methods: ["POST"],
        path: "/acknowledge"
    }
    acknowledgeInvitation (endpoint caller, http:Request request) {
        http:Response response = new;

        json jsonPayload = check request.getJsonPayload();
        string textPayload = jsonPayload.toString();

        mb:Message invitationMessage = check invitationAcknowledgeQueueSender.createTextMessage(textPayload);
        invitationAcknowledgeQueueSender -> send(invitationMessage) but {
            error e => log:printError("Error sending message to the InvitationAcknowledgeQueue", err = e)
        };

        response.setTextPayload("Request has been submitted, you will be notified via email", contentType = "text/plain");

        caller -> respond(response) but {
            error e => log:printError("Error sending response back to the caller", err = e)
        };
    }
}
