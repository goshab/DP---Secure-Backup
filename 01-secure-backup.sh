#!/bin/bash
##################################################################################
# This DataPower automation performs the following activities:
#  * creates a DataPower Secure Backup
#  * downloads the Secure Backup files
#  * uploads the files to a git repo
##################################################################################
# Prerequisites:
#   curl (v7.79.1)
#   xmlstarlet
##################################################################################
# by Gosha Belenkiy
##################################################################################
log_to_file() {
    MSG=$1

    TIME=$(date +'%Y-%m-%dT%H:%M:%S')
    echo "$TIME $MSG" >> $LOG_FILE
}
log(){
    MSG=$1

    TIME=$(date +'%Y-%m-%dT%H:%M:%S')
    echo -e "$TIME $MSG"
}
log_title() {
    MSG=$1

    log_to_file "$MSG"
    log $BLUE"$MSG"$NC
}
log_info() {
    MSG=$1

    log_to_file "$MSG"
    log $PURPLE"$MSG"$NC
}
log_error() {
    MSG=$1

    log_to_file "$MSG"
    log $RED"$MSG"$NC
}
log_success() {
    MSG=$1

    log_to_file "$MSG"
    log $GREEN"$MSG"$NC
}
##################################################################################
# Send SOMA command
##################################################################################
runSoma() {
    DP_USERNAME=$1
    DP_PASSWORD=$2
    DP_SOMA_URL=$3
    DP_SOMA_REQ=$4
    DP_SOMA_REQ_FILENAME=$5
    EXTRA_CURL_ARGS=$6
    VALIDATE_OUTPUT=$7

    soma_cli="curl -s -k $EXTRA_CURL_ARGS $DP_SOMA_URL"
    if [ ! -z "$DP_SOMA_REQ" ]; then
        soma_cli="${soma_cli} -X POST -d '${DP_SOMA_REQ}'"
    fi

    if [ ! -z "$DP_SOMA_REQ_FILENAME" ]; then
        soma_cli="$soma_cli -T '${DP_SOMA_REQ_FILENAME}'"
    fi
    soma_cli="$soma_cli -u $DP_USERNAME:$DP_PASSWORD"
    if [ "$DEBUG" = "true" ]; then
        log_to_file "runSoma() SOMA curl cli=${soma_cli}"
    fi
    soma_response=$(eval $soma_cli)

    if [ "$DEBUG" = "true" ]; then
        log_to_file "runSoma() SOMA response=${soma_response}"
    fi
    echo $soma_response
}
##################################################################################
# SOMA - Run Secure Backup
##################################################################################
somaSecureBackup() {
    DP_USERNAME=$1
    DP_PASSWORD=$2
    DP_SOMA_URL=$3
    DP_CERTIFICATE=$4
    DP_SB_DST_FOLDER=$5

    SOMA_REQ=$(cat <<-EOF
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:dp="http://www.datapower.com/schemas/management">
    <soapenv:Body>
		<dp:request domain="default">
			<dp:do-action>
				<SecureBackup>
					<cert>$DP_CERTIFICATE</cert>
					<destination>$DP_SB_DST_FOLDER</destination>
					<include-iscsi>$INCLUDE_ISCSI</include-iscsi>
					<include-raid>$INCLUDE_RAID</include-raid>
				</SecureBackup>
			</dp:do-action>
		</dp:request>
    </soapenv:Body>
</soapenv:Envelope>
EOF
)

    declare -a soma_response="$(runSoma $DP_USERNAME $DP_PASSWORD $DP_SOMA_URL "${SOMA_REQ}" '' '' '' 'false')"
    echo $soma_response
}
##################################################################################
# SOMA - Get DataPower firmware status
##################################################################################
somaGetFirmwareStatus() {
    DP_USERNAME=$1
    DP_PASSWORD=$2
    DP_SOMA_URL=$3

    SOMA_REQ=$(cat <<-EOF
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:dp="http://www.datapower.com/schemas/management">
    <soapenv:Body>
        <dp:request>
            <dp:get-status class="FirmwareStatus"/>
        </dp:request>
    </soapenv:Body>
</soapenv:Envelope>
EOF
)

    declare -a soma_response="$(runSoma $DP_USERNAME $DP_PASSWORD $DP_SOMA_URL "${SOMA_REQ}" '' '' '' 'false')"
    echo $soma_response
}
##################################################################################
# SOMA - Get File
##################################################################################
somaGetFile() {
    DP_USERNAME=$1
    DP_PASSWORD=$2
    DP_SOMA_URL=$3
    DP_DOMAIN=$4
    DP_FILE=$5

    SOMA_REQ=$(cat <<-EOF
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:dp="http://www.datapower.com/schemas/management">
    <soapenv:Body>
        <dp:request domain="$DP_DOMAIN">
            <dp:get-file name="$DP_FILE"/>
        </dp:request>
    </soapenv:Body>
</soapenv:Envelope>
EOF
)

    declare -a soma_response="$(runSoma $DP_USERNAME $DP_PASSWORD $DP_SOMA_URL "${SOMA_REQ}" '' '' '' 'false')"
    echo $soma_response
}
##################################################################################
# Main section
##################################################################################
if [ -z "$1" ]; then
    echo "Syntax error, aborting."
    echo "  Provide configuration filename as a parameter"
    exit
fi

if [ ! -f ./$1 ]; then
    echo "Configuration file $1 not found, aborting."
    exit
fi

. ./system.conf
. $1

if [ "$EMPTY_LOG_FILE_ON_START" = "true" ]; then
    printf "" > $LOG_FILE
fi

if [ -z "$DP_USER_SERVER0" ]; then
    read -p "Enter the DataPower user name: " DP_USER_SERVER0
fi

if [ -z "$DP_PASSWORD_SERVER0" ]; then
    read -sp "Enter the DataPower user password: " DP_PASSWORD_SERVER0
    echo
fi

log_title "====================================================================================="
log_title "Secure Backup the DataPower Gateway"
log_title "====================================================================================="
log_info "Start: $(date)"
log_info "DataPower: $DP_SERVER0"
log_info "DataPower Secure Backup folder: $DP_SB_FOLDER"
log_info "====================================================================================="

# Get the DataPower firmware details
log_title "Checking firmware status"
declare -a soma_resp_firmware_status="$(somaGetFirmwareStatus $DP_USER_SERVER0 $DP_PASSWORD_SERVER0 $DP_SOMA_URL)"
soma_response_analysis=$(echo $soma_resp_firmware_status | grep -o '</FirmwareStatus>')
if [ "${#soma_response_analysis}" = 0 ]; then
    log_error "Failure"
    log_error "$soma_resp_firmware_status"
    exit
fi
firmware_version=$(echo $soma_resp_firmware_status | xmlstarlet sel -t -v "//Version")

log_success "Firmware version: $firmware_version"
log_info "====================================================================================="
# Send the Secure Backup request
log_title "Creating a Secure Backup"
declare -a soma_response="$(somaSecureBackup $DP_USER_SERVER0 $DP_PASSWORD_SERVER0 $DP_SOMA_URL $DP_CERTIFICATE_SERVER0 $DP_SB_FOLDER)"

soma_response_analysis=$(echo $soma_response | grep -o 'OK')
if [ ! "$soma_response_analysis" = "OK" ]; then
    log_error "Failure"
    log_error "$soma_response"
    exit
fi
log_success "Success"
log_info "====================================================================================="

# Download the Secure Backup manifest file
log_title "Downloading Secure Backup files"
LOCAL_SB_FOLDER=$DP_SERVER0/$firmware_version/$SB_FOLDER
log_info "Local Secure Backup folder: $LOCAL_SB_FOLDER"

mkdir -p $LOCAL_SB_FOLDER
log_info "Downloading $DP_SB_FOLDER/backupmanifest.xml"
DP_FILE_TO_GET="$DP_SB_FOLDER/backupmanifest.xml"
declare -a soma_response_get_file="$(somaGetFile $DP_USER_SERVER0 $DP_PASSWORD_SERVER0 $DP_SOMA_URL "default" "$DP_FILE_TO_GET")"
analysis=$(echo "$soma_response_get_file" | grep -o "$DP_FILE_TO_GET")
if [ ! "$analysis" = "$DP_FILE_TO_GET" ]; then
    log_error "File download failed"
    log_error "$soma_response_get_file"
    exit
fi
log_success "File downloaded successfully"

backupmanifest_b64=$(echo $soma_response_get_file | xmlstarlet sel -t -v "/*[local-name()='Envelope']/*[local-name()='Body']/*[local-name()='response']/*[local-name()='file']")
backupmanifest_xml=$(echo $backupmanifest_b64 | base64 -d)
mkdir -p $LOCAL_SB_FOLDER
echo $backupmanifest_xml > $LOCAL_SB_FOLDER/backupmanifest.xml

# Download all Secure Backup files per the manifest
xmlstarlet sel -t -v '//backupmanifest/files/file/filename' --nl $LOCAL_SB_FOLDER/backupmanifest.xml |
while IFS= read -r cur_file; do
    DP_FILE_TO_GET="$DP_SB_FOLDER/$cur_file"
    log_info "Downloading $DP_FILE_TO_GET"
    declare -a soma_response_get_file="$(somaGetFile $DP_USER_SERVER0 $DP_PASSWORD_SERVER0 $DP_SOMA_URL "default" "$DP_FILE_TO_GET")"
    analysis=$(echo "$soma_response_get_file" | grep -o "$DP_FILE_TO_GET")
    if [ ! "$analysis" = "$DP_FILE_TO_GET" ]; then
        log_error "File download failed"
        log_error "$soma_response_get_file"
        exit
    fi
    log_success "File downloaded successfully"
    file_b64=$(echo $soma_response_get_file | xmlstarlet sel -t -v "/*[local-name()='Envelope']/*[local-name()='Body']/*[local-name()='response']/*[local-name()='file']")
    file_decoded=$(echo $file_b64 | base64 -d)
    echo $file_decoded > $LOCAL_SB_FOLDER/$cur_file
done
log_info "====================================================================================="
log_info "Downloaded Secure Backup files:"
log_info "$(ls -lh $LOCAL_SB_FOLDER)"
log_info "====================================================================================="

if [ "$ADD_TO_GIT" = "true" ]; then
    log_title "Pushing Secure Backup files to git repository"
    log_info "Git remote=$GIT_REMOTE_NAME git branch=$GIT_BRANCH_NAME"
    git pull $GIT_REMOTE_NAME $GIT_BRANCH_NAME
    git add $LOCAL_SB_FOLDER\*
    git commit -m "Automated push"
    git push $GIT_REMOTE_NAME $GIT_BRANCH_NAME
    log_info "====================================================================================="
fi

log_info "End: $(date)"
log_title "====================================================================================="
