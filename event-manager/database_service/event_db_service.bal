import ballerina/http;
import ballerina/sql;
import ballerina/mysql;
import ballerina/config;
import ballerina/log;

type User record {
    string email;
    string name;
    string company;
    boolean response;
};

endpoint mysql:Client eventDBEndpoint {
    host: config:getAsString("event_db.DATABASE_HOST"),
    port: config:getAsInt("event_db.DATABASE_PORT"),
    name: config:getAsString("event_db.DATABASE_NAME"),
    username: config:getAsString("event_db.DATABASE_USERNAME"),
    password: config:getAsString("event_db.DATABASE_PASSWORD"),
    dbOptions: { useSSL: false }
};

endpoint http:Listener eventDBServiceEndpoint {
    port: 9091
};

@http:ServiceConfig {
    basePath: "/event"
}
service<http:Service> eventDBService bind eventDBServiceEndpoint {
    @http:ResourceConfig {
        methods: ["POST"],
        path: "/users"
    }
    addUser (endpoint caller, http:Request request) {
        http:Response addUserResponse = new;
        json jsonPayload = check request.getJsonPayload();

        match <User>jsonPayload {
            User userData => {
                json jsonResponse = insertData(userData.email, userData.name, userData.company, 
                    userData.response);
                int statusCode = check <int>jsonResponse.code;
                if (statusCode != 200) {
                    addUserResponse.statusCode = statusCode;
                }
                addUserResponse.setJsonPayload(jsonResponse, contentType = "application/json");
                caller -> respond(addUserResponse) but {
                    error e => log:printError("Error sending response back to the caller", err = e)
                };
            }
            error err => {
                addUserResponse.setJsonPayload({"Error" : "json payload should contain email:<string>, name:<string>, company:<string>, response:<boolean>"});
                addUserResponse.statusCode = 400;
                caller -> respond(addUserResponse) but {
                    error e => log:printError("Error sending response back to the caller", err = e)
                };
            }
        }
    }

    @http:ResourceConfig {
        methods: ["PUT"],
        path: "/users"
    }
    updateUser (endpoint caller, http:Request request) {
        http:Response updateUserResponse = new;
        json jsonPayload = check request.getJsonPayload();

        match <User>jsonPayload {
            User userData => {
                json jsonResponse = updateData(userData.email, userData.name, userData.company, 
                    userData.response);
                int statusCode = check <int>jsonResponse.code;
                if (statusCode != 200) {
                    updateUserResponse.statusCode = statusCode;
                }
                updateUserResponse.setJsonPayload(jsonResponse, contentType = "application/json");
                caller -> respond(updateUserResponse) but {
                    error e => log:printError("Error sending response back to the caller", err = e)
                };
            }
            error err => {
                updateUserResponse.setJsonPayload({"Error" : "json payload should contain email:<string>, name:<string>, company:<string>, response:<boolean>"});
                updateUserResponse.statusCode = 400;
                caller -> respond(updateUserResponse) but {
                    error e => log:printError("Error sending response back to the caller", err = e)
                };
            }
        }
    }

    @http:ResourceConfig {
        methods: ["GET"],
        path: "/users/accept-count"
    }
    getAcceptedUserCount (endpoint caller, http:Request request) {
        http:Response userCountResponse = new;
        json jsonResponse = retrieveAcceptedUserCount();
        int statusCode = check <int>jsonResponse.code;
        if (statusCode != 200) {
            userCountResponse.statusCode = statusCode;
        }
        userCountResponse.setJsonPayload(untaint jsonResponse);
        caller -> respond(untaint userCountResponse) but {
            error e => log:printError("Error sending response back to the caller", err = e)
        };
    }
}

function insertData (string email, string name, string company, boolean response) returns (json) {
    json insertStatus;
    string sqlQuery = "INSERT INTO users values (?, ?, ?, ?)";
    var dbResponse = eventDBEndpoint->update(sqlQuery, email, name, company, response);

    match dbResponse {
        int insertRowCount => {
            insertStatus = { "code": 200, "status": "successful", "records": insertRowCount };
        }
        error err => {
            insertStatus = { "code": 500, "status": "Failed", "error": err.message };
            log:printError("Error trying to insert user", err = err);
        }
    }
    return insertStatus;
}

function updateData (string email, string name, string company, boolean response) returns (json) {
    json updateStatus;
    string sqlQuery = "UPDATE users SET name = ?, company = ?, response = ? WHERE email = ?";
    var dbResponse = eventDBEndpoint->update(sqlQuery, name, company, response, email);

    match dbResponse {
        int insertRowCount => {
            updateStatus = { "code": 200, "status": "Successful", "records": insertRowCount };
        }
        error err => {
            updateStatus = { "code": 500, "status": "Failed", "error": err.message };
            log:printError("Error trying to update user", err = err);
        }
    }
    return updateStatus;
}

function retrieveAcceptedUserCount () returns (json) {
    json value;
    string sqlQuery = "SELECT COUNT(*) as user_count FROM users WHERE response = 1";
    var dbResponse = eventDBEndpoint->select(sqlQuery, ());

    match dbResponse {
        table dataTable => {
            json response = check <json>dataTable;
            value = { "code": 200, "status": "Successful", "records": response[0].user_count };
        }
        error err => {
            value = { "code": 500, "status": "Failed", "error": err.message };
            log:printError("Error trying to retreive accepted user count", err = err);
        }
    }
    return value;
}
