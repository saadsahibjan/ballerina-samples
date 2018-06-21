import ballerina/mb;
import ballerina/log;

endpoint mb:SimpleQueueReceiver invitationAcknowledgeQueueReceiver {
    host: "localhost",
    port: 5672,
    queueName: "InvitationAcknowledgeQueue"
};

service<mb:Consumer> seatReservationListener bind invitationAcknowledgeQueueReceiver {
    onMessage (endpoint consumer, mb:Message mbMessage) {
        string textPayload = check mbMessage.getTextMessageContent();
        log:printInfo("[INVITATION ACKNOWLEDGE QUEUE] Reservation Details: " + textPayload);
    }
}
