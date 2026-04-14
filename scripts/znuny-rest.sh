#!/bin/bash

# Base URL
BASE_URL="http://localhost:31810/znuny/nph-genericinterface.pl/Webservice/generic"

# API Credentials
USER_LOGIN="root"
PASSWORD="admin"

# =============================================================================
# 1. Create Session
# =============================================================================
create_session() {
    curl -X POST "${BASE_URL}/Session" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -H "X-OTRS-Header-UserLogin: ${USER_LOGIN}" \
        -H "X-OTRS-Header-Password: ${PASSWORD}"
    echo ""
}

# =============================================================================
# 2. Create Ticket
#
# =============================================================================
create_ticket() {
    # First create a session and capture the session ID
    SESSION_ID=$(curl -s -X POST "${BASE_URL}/Session" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -H "X-OTRS-Header-UserLogin: ${USER_LOGIN}" \
        -H "X-OTRS-Header-Password: ${PASSWORD}" \
        | jq -r '.SessionID')

    if [ -z "$SESSION_ID" ] || [ "$SESSION_ID" = "null" ]; then
        echo "Failed to create session"
        return 1
    fi

    echo "Session ID: ${SESSION_ID}"

    # Create ticket using the session ID
    curl -X POST "${BASE_URL}/Ticket" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -H "X-SessionID: ${SESSION_ID}" \
        -d "{
            \"UserLogin\": \"${USER_LOGIN}\",
            \"Password\": \"${PASSWORD}\",
            \"Ticket\": {
                \"QueueID\": \"2\",
                \"StateID\": \"1\",
                \"OwnerID\": \"1\",
                \"TypeID\": \"1\",
                \"PriorityID\": \"3\",
                \"Title\": \"Test\",
                \"CustomerUser\": \"andreas@add.de\",
                \"Lock\": \"unlock\"
            },
            \"Article\": {
                \"CommunicationChannel\": \"Internal\",
                \"SenderType\": \"agent\",
                \"Subject\": \"Initial Request\",
                \"Body\": \"Test Body\ngreetings by Dr. Schiffler\",
                \"From\": \"admin@add.de\",
                \"To\": \"user@znuny.example.com\",
                \"VisibleForCustomer\": \"0\",
                \"ContentType\": \"text/plain; charset=utf8\"
            }
        }"
    echo ""
}

# =============================================================================
# 3. Update Ticket with Text File
# =============================================================================
update_ticket_with_file() {
    local TICKET_ID="$1"
    local FILE_PATH="$2"

    if [ -z "$TICKET_ID" ]; then
        echo "Error: Ticket ID is required"
        echo "Usage: $0 update-ticket <ticket_id> <file_path>"
        return 1
    fi

    if [ -z "$FILE_PATH" ]; then
        echo "Error: File path is required"
        echo "Usage: $0 update-ticket <ticket_id> <file_path>"
        return 1
    fi

    if [ ! -f "$FILE_PATH" ]; then
        echo "Error: File not found: $FILE_PATH"
        return 1
    fi

    # Read file content and encode to base64
    local FILE_CONTENT
    FILE_CONTENT=$(base64 -w 0 "$FILE_PATH")
    local FILENAME
    FILENAME=$(basename "$FILE_PATH")

    # First create a session and capture the session ID
    local SESSION_ID
    SESSION_ID=$(curl -s -X POST "${BASE_URL}/Session" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -H "X-OTRS-Header-UserLogin: ${USER_LOGIN}" \
        -H "X-OTRS-Header-Password: ${PASSWORD}" | jq -r '.SessionID')

    if [ -z "$SESSION_ID" ] || [ "$SESSION_ID" = "null" ]; then
        echo "Failed to create session"
        return 1
    fi

    echo "Updating ticket $TICKET_ID with file: $FILENAME"

    # Create temporary file for request body
    TEMP_FILE=$(mktemp)
    cat > "$TEMP_FILE" << EOF
{
    "UserLogin": "${USER_LOGIN}",
    "Password": "${PASSWORD}",
    "Article": {
        "CommunicationChannel": "Internal",
        "SenderType": "agent",
        "Subject": "Updated from file: ${FILENAME}",
        "Body": "Please find the attached document.",
        "ContentType": "text/plain; charset=utf8",
        "Attachment": [
            {
                "Content": "${FILE_CONTENT}",
                "ContentType": "application/pdf",
                "Filename": "${FILENAME}"
            }
        ]
    }
}
EOF

    # Update ticket using the session ID
    curl -X PATCH "${BASE_URL}/Ticket/${TICKET_ID}" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -H "X-SessionID: ${SESSION_ID}" \
        --data-binary "@${TEMP_FILE}"
    rm -f "$TEMP_FILE"
    echo ""
}

# =============================================================================
# 4. Search Tickets
# =============================================================================
search_tickets() {
    local QUEUE_IDS="${1:-}"
    local KEYWORD="$2"
    local KEYWORD2="$3"

    # First create a session and capture the session ID
    local SESSION_ID
    SESSION_ID=$(curl -s -X POST "${BASE_URL}/Session" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -d "{
            \"UserLogin\": \"${USER_LOGIN}\",
            \"Password\": \"${PASSWORD}\"
        }" | jq -r '.SessionID')

    if [ -z "$SESSION_ID" ] || [ "$SESSION_ID" = "null" ]; then
        echo "Failed to create session"
        return 1
    fi

    echo "Search with session ID: ${SESSION_ID}"

    # Build queue IDs JSON array
    local QUEUE_JSON="[]"
    if [ -n "$QUEUE_IDS" ]; then
        # Convert comma-separated list to JSON array
        QUEUE_JSON=$(echo "$QUEUE_IDS" | tr ',' '\n' | awk '{printf "\"%s\",", $0}' | sed 's/,$//' | sed 's/^/[/' | sed 's/$/]/')
    fi

    echo "Search for ExternalCaseNumber: \"${KEYWORD}\" and Aktenzeichen: \"${KEYWORD2}\" in queue with numbers [${QUEUE_IDS}]"

    # Search tickets using the session ID
    curl -X POST "${BASE_URL}/Search" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -d "{
            \"SessionID\": \"${SESSION_ID}\",
            \"DynamicField_ExternalCaseNumber\": 
                {
                \"Equals\": \"${KEYWORD}\"
                },
            \"DynamicField_RefID\": 
                {
                \"Equals\": \"${KEYWORD2}\"
                }
        }"
    echo ""
}

# =============================================================================
# Usage
# =============================================================================
case "$1" in
    session)
        create_session
        ;;
    ticket)
        create_ticket
        ;;
    update-ticket)
        update_ticket_with_file "$2" "$3"
        ;;
    search)
        search_tickets "$2" "$3" "$4"
        ;;
    *)
        echo "Usage: $0 {session|ticket|update-ticket <ticket_id> <file_path>|search [queue_ids]}"
        echo ""
        echo "Commands:"
        echo "  session              - Create a new session"
        echo "  ticket               - Create a new ticket"
        echo "  update-ticket        - Update a ticket with a file"
        echo "  search               - Search tickets (optional: queue_ids as comma-separated list)"
        echo ""
        echo "Examples:"
        echo "  $0 session"
        echo "  $0 ticket"
        echo "  $0 update-ticket 12345 /path/to/file.txt"
        echo "  $0 search"
        echo "  $0 search 1,2,3"
        ;;
esac

