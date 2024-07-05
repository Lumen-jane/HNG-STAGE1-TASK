#!/bin/bash

# Autogenerate Password and Metrics will be sent here
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.csv"

# Function to generate random password
generate_password() {
    echo $(openssl rand -base64 12)
}

# Create directories with proper permissions
create_directories() {
    if [ ! -d "/var/secure" ]; then
        sudo mkdir -p /var/secure
        sudo chmod 700 /var/secure
    fi
    sudo touch $LOG_FILE
    sudo touch $PASSWORD_FILE
    sudo chmod 600 $PASSWORD_FILE
}

# Initialize directories and files
create_directories

# Read the input file, which is the <users> file we created to be dependent on our bash script code function execution
INPUT_FILE=$1

if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Input file not found!"
    exit 1
fi

# Debugging: Print the input file being processed
echo "Processing input file: $INPUT_FILE"

# Process each line in the input file
while IFS=';' read -r user groups; do
    # Trim whitespace
    user=$(echo "$user" | xargs)
    groups=$(echo "$groups" | xargs)

    # Debugging: Print the user and groups being processed
    echo "Processing user: $user with groups: $groups"

    # Ensure a personal group for each user
    if ! getent group "$user" > /dev/null; then
        echo "Creating personal group for user: $user"
        sudo groupadd "$user"
    fi

    # Create user with home directory and primary group
    if ! id "$user" &>/dev/null; then
        sudo useradd -m -g "$user" "$user"
        echo "User $user was created successfully." | sudo tee -a $LOG_FILE
    else
        echo "User $user already exists." | sudo tee -a $LOG_FILE
    fi

    # Ensure specified groups exist and add user to groups
    IFS=',' read -ra group_array <<< "$groups"
    for group in "${group_array[@]}"; do
        group=$(echo "$group" | xargs)  # Trim whitespace
        if [ ! -z "$group" ]; then
            if ! getent group "$group" > /dev/null; then
                echo "Creating group: $group"
                sudo groupadd "$group"
            fi
            sudo usermod -aG "$group" "$user"
            echo "User $user added to group: $group." | sudo tee -a $LOG_FILE
        fi
    done

    # Auto Generate and set password
    password=$(generate_password)
    echo "$user:$password" | sudo chpasswd
    echo "$user,$password" | sudo tee -a $PASSWORD_FILE
    echo "Password for user $user set." | sudo tee -a $LOG_FILE

done < "$INPUT_FILE"

