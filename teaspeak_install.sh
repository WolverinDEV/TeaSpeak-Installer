#!/bin/bash

INSTALLER_VERSION="1.10"

function debug() {
    echo "debug > ${@}"
}

function warn() {
    echo -e "\\033[33;1m${@}\033[0m"
}

function error() {
    echo -e "\\033[31;1m${@}\033[0m"
}

function info() {
    echo -e "\\033[36;1m${@}\033[0m"
}

function cursor_up() {
    tput cuu $1
}

# Colors.
function greenMessage() {
    echo -e "\\033[32;1m${@}\033[0m"
}

function cyanMessage() {
    echo -e "\\033[36;1m${@}\033[0m"
}

function redMessage() {
    echo -e "\\033[31;1m${@}\033[0m"
}

function yellowMessage() {
    echo -e "\\033[33;1m${@}\033[0m"
}

# Errors, warnings and info.
function errorExit() {
    redMessage ${@}
    exit 1
}

function option_quit_installer() {
    redMessage "TeaSpeak Installer closed."
    exit 0
}

function invalidOption() {
    redMessage "Invalid option. Try another one."
}

function redWarnAnim() {
    redMessage $1
    sleep 1
}

function greenOkAnim() {
    greenMessage $1
    sleep 1
}

function yellowOkAnim() {
    yellowMessage $1
    sleep 1
}

#FIXME test for sudo or root
SUDO_PREFIX="sudo "

function detect_packet_manager() {
    # Check supported Linux distributions and package manager.
    PACKET_MANAGER_NAME=""
    PACKET_MANAGER_TEST=""
    PACKET_MANAGER_UPDATE=""
    PACKET_MANAGER_INSTALL=""

    SUPPORT_LIBAV=false
    SUPPORT_FFMPEG=false

    #<system name>|<support: libav | ffmpeg>|<managers...> (command seperated by :)
    PACKET_MANAGERS=(
        "Debian|libav:ffmpeg|apt:dpkg-query"
        "Ubuntu|libav:ffmpeg|apt:dpkg-query"
        "openSUSE||yzpper"
    )
    PACKET_MANAGER_COMMANDS=(
        "apt:dpkg-query|dpkg-query -s %s||apt install %s"
        "yzpper|zypper se --installed-only %s||zypper in %s"
    )
    SYSTEM_NAME=$(cat /etc/*release | grep ^NAME | awk -F '["]' '{print $2}')
    SYSTEM_NAME_DETECTED="" #Give the system out own name :D


    for system in ${PACKET_MANAGERS[@]}
    do
        IFS='|' read -r -a data <<< $system
        debug "Testing ${system} => ${data[0]}"

        if echo "${SYSTEM_NAME}" | grep "${data[0]}" &>/dev/null; then
            SYSTEM_NAME_DETECTED="${data[0]}"
        else
            continue
        fi

        debug "Found system ${data[0]}"
        for index in $(seq 2 ${#data[@]})
        do
            PACKET_MANAGER_NAME=${data[${index}]}

            debug "Testing commands ${PACKET_MANAGER_NAME}"
            for command in ${PACKET_MANAGER_NAME//:/ }
            do
                debug "Testing command ${command}"
                if ! [ $(command -v ${command}) >/dev/null 2>&1 ]; then
                    PACKET_MANAGER_NAME=""
                    break
                fi
            done
            if [ ${PACKET_MANAGER_NAME} != "" ]; then
                break
            fi
        done

        if ! [ "${PACKET_MANAGER_NAME}" == "" ]; then
            echo "${data[1]}" | grep "libav" />/dev/null
            if [ $? -ne 0 ]; then
                SUPPORT_LIBAV=true
            fi
            echo "${data[1]}" | grep "ffmpeg" />/dev/null
            if [ $? -ne 0 ]; then
                SUPPORT_FFMPEG=true
            fi
            break
        fi
    done

    if [ "${PACKET_MANAGER_NAME}" == "" ]; then
        error "Failed to determinate your system and the packet manager on it! (System: ${SYSTEM_NAME})"
        return 1
    fi

    IFS='~'
    for manager_commands in ${PACKET_MANAGER_COMMANDS[@]}
    do
        IFS='|' read -r -a commands <<< $manager_commands

        if [ "${commands[0]}" == "${PACKET_MANAGER_NAME}" ]; then
            PACKET_MANAGER_INSTALL="${commands[3]}"
            PACKET_MANAGER_UPDATE="${commands[3]}"
            PACKET_MANAGER_TEST="${commands[1]}"
            break
        fi
    done

    if [ "${PACKET_MANAGER_INSTALL}" == "" ]; then
        error "Failed to find packet manager commands for manager (${PACKET_MANAGER_NAME})"
        return 1
    fi

    info "Got packet manager commands:"
    info "Install            : ${PACKET_MANAGER_INSTALL}"
    info "Update             : ${PACKET_MANAGER_UPDATE}"
    info "Test               : ${PACKET_MANAGER_TEST}"
    info "Lib AV support     : ${SUPPORT_LIBAV}"
    info "Lib ffmpeg support : ${SUPPORT_FFMPEG}"
    return 0

    #FIXME: Remove this stuff here and enter the commands above
    cyanMessage " "
    if cat /etc/*release | grep ^NAME | grep Debian &>/dev/null; then # Debian Distribution
        OS=Debian
        PM=apt
        PM2=dpkg
        greenOkAnim "${OS} detected!"
        if { command -v ${PM} && command -v ${PM2} --help; } >/dev/null 2>&1; then
            yellowOkAnim "Using ${PM} package manager."
            osID=1
            pmID=1
        else
            errorExit "${OS} detected, but the ${PM} or ${PM2} package manager is missing!"
        fi
    elif cat /etc/*release | grep ^NAME | grep Ubuntu &>/dev/null; then # Ubuntu Distribution
        OS=Ubuntu
        PM=apt
        PM2=dpkg
        greenOkAnim "Ubuntu detected!"
        if { command -v ${PM} && command -v ${PM2} --help; } >/dev/null 2>&1; then
            yellowOkAnim "Using ${PM} package manager."
            osID=2
            pmID=1
        else
            errorExit "${OS} detected, but the ${PM} or ${PM2} package manager is missing!"
        fi
    elif cat /etc/*release | grep ^NAME | grep openSUSE &>/dev/null; then # openSUSE Distribution
        OS=openSUSE
        PM=yzpper
        PM2=rpm
        greenOkAnim "openSUSE detected!"
        if { command -v ${PM} && command -v ${PM2} --help; } >/dev/null 2>&1; then
            yellowOkAnim "Using ${PM} package manager."
            osID=3
            pmID=2
        else
            errorExit "${OS} detected, but the ${PM} or ${PM2} package manager is missing!"
        fi
    elif cat /etc/*release | grep ^NAME | grep CentOS &>/dev/null; then # CentOS Distribution
        OS=CentOS
        PM=yum
        PM2=rpm
        greenOkAnim "CentOS detected!"
        if { command -v ${PM} && command -v ${PM2} --help; } >/dev/null 2>&1; then
            yellowOkAnim "Using ${PM} package manager."
            osID=4
            pmID=3
        else
            errorExit "${OS} detected, but the ${PM} or ${PM2} package manager is missing!"
        fi
    elif cat /etc/*release | grep ^NAME | grep Red &>/dev/null; then  # RedHat Distribution
        OS=RedHat
        PM=yum
        PM2=rpm
        greenOkAnim "RedHat detected!"
        if { command -v ${PM} && command -v ${PM2} --help; } >/dev/null 2>&1; then
            yellowOkAnim "Using ${PM} package manager."
            osID=5
            pmID=3
        else
            errorExit "${OS} detected, but the ${PM} or ${PM2} package manager is missing!"
        fi
    elif cat /etc/*release | grep ^NAME | grep Arch &>/dev/null; then # Arch Distribution
        OS=Arch
        PM=pacman
        greenOkAnim "Arch detected!"
        if { command -v ${PM}; } >/dev/null 2>&1; then
            yellowOkAnim "Using ${PM} package manager."
            osID=6
            pmID=5
        else
            errorExit "${OS} detected, but the ${PM} package manager is missing!"
        fi
    elif cat /etc/*release | grep ^NAME | grep Fedora &>/dev/null; then # Fedora Distribution
        OS=Fedora
        PM=dnf
        PM2=rpm
        greenOkAnim "Fedora detected!"
        if { command -v ${PM} && command -v ${PM2} --help; } >/dev/null 2>&1; then
            yellowOkAnim "Using ${PM} package manager."
            osID=7
            pmID=4
        else
            errorExit "${OS} detected, but the ${PM} or ${PM2} package manager is missing!"
        fi
    elif cat /etc/*release | grep ^NAME | grep Mint &>/dev/null; then # Mint Distribution
        OS=Mint
        PM=apt
        PM2=dpkg
        greenOkAnim "Mint detected!"
        if { command -v ${PM} && command -v ${PM2} --help; } >/dev/null 2>&1; then
            yellowOkAnim "Using ${PM} package manager."
            osID=8
            pmID=1
        else
            errorExit "${OS} detected, but the ${PM} or ${PM2} package manager is missing!"
        fi
    else
        errorExit "This Distribution is not supported!"
    fi
}

function test_installed() {
    local require_install=()

    for package in "${@}"
    do
        local command=$(printf ${PACKET_MANAGER_TEST} "${package}")
        debug ${command}
        eval "${command}" &>/dev/null
        if [ $? -ne 0 ]; then
            warn "Missing required package ${package}"
            require_install+=(${package})
        fi
    done

    if [ ${#require_install[@]} -lt 1 ]; then
        echo ${#require_install[@]}
        return 0
    fi

    packages=$(printf " %s" "${require_install[@]}")
    packages=${packages:1}

    packages_human=$(printf ", \"%s\"" "${require_install[@]}")
    packages_human=${packages_human:2}

    greenMessage "${packages_human} are missing! Should we install that for you? (Required root or administrator privileges)"
    OPTIONS=("Yes" "No")
    select OPTION in "${OPTIONS[@]}"; do
        case "$REPLY" in
            1|2) break;;
            *)  invalidOption; continue;;
        esac
    done

    if [ "$OPTION" == "${OPTIONS[0]}" ]; then
        local command=$(printf ${PACKET_MANAGER_INSTALL} "${packages}")
        debug ${SUDO_PREFIX} ${command}
        eval "${SUDO_PREFIX} ${command}"
        if [ $? -ne 0 ]; then
            error "Failed to install required packages!"
            error "Quitting script"
            exit 1
        fi
        return 0
    fi
    return 2
}

function updateScript() {
    INSTALLER_REPO_URL="https://api.github.com/repos/Sporesirius/TeaSpeak-Installer/releases/latest"
    INSTALLER_REPO_PACKAGE="https://github.com/Sporesirius/TeaSpeak-Installer/archive/%s.tar.gz"

    info " "
    info "Checking for the latest installer version..."

    LATEST_VERSION=$(wget -q --timeout=60 -O - ${INSTALLER_REPO_URL} | grep -Po '(?<="tag_name": ")([0-9]\.[0-9]+)')
    if [ $? -ne 0 ]; then
        warn "Failed to check for updates for this script!"
        return 1
    fi

    if [ "`printf "${LATEST_VERSION}\n${INSTALLER_VERSION}" | sort -V | tail -n 1`" != "$INSTALLER_VERSION" ]; then
        redMessage "New version ${LATEST_VERSION} available!"
        yellowMessage "You are using the version ${INSTALLER_VERSION}."
        cyanMessage " "
        cyanMessage "Do you want to update the installer script?"
        OPTIONS=("Download" "Skip" "Quit")
        select OPTION in "${OPTIONS[@]}"; do
            case "$REPLY" in
                1|2 ) break;;
                3 ) option_quit_installer;;
                *)  invalidOption; continue;;
            esac
        done

        if [ "$OPTION" == "${OPTIONS[0]}" ]; then
            info " "
            info "# Downloading new installer version..."
            wget --timeout=60 `printf ${INSTALLER_REPO_PACKAGE} "${LATEST_VERSION}"` -O installer_latest.tar.gz
            if [ $? -ne 0 ]; then
                warn "Failed to download update. Update failed!"
                return 1
            fi
            info "Done!"

            info " "
            info "# Unpacking installer and replace the old installer with the new one."
            tar -xzf installer_latest.tar.gz
            rm installer_latest.tar.gz
            cp TeaSpeak-Installer-*/teaspeak_install.sh teaspeak_install.sh
            rm -r TeaSpeak-Installer-*
            info "Done!"

            info " "
            info "# Adjustign script rights for execution."
            chmod 774 teaspeak_install.sh

            info " "
            info "# Restarting update script!"
            sleep 3
            clear
            ./teaspeak_install.sh
            exit 0
        elif [ "$OPTION" == ${OPTIONS[1]} ]; then
            yellowOkAnim "New installer version skiped."
        else
            exit 1
        fi
    else
        info "# You are using the up to date version ${INSTALLER_VERSION}."
    fi
}

cyanMessage " "
cyanMessage " "
redMessage "        TeaSpeak Installer"
cyanMessage "       by Sporesirius and WolverinDEV"
cyanMessage " "

#FIXME to the top with the sudo preifx!
# We need root or sudo privileges to run the installer.
if ! sudo -S -p '' echo -n < /dev/null 2> /dev/null ; [ "`id -u`" != "0" ] ; then
    errorExit "Root or sudo privileges are required to run the install script!"
fi

detect_packet_manager
if [ $? -ne 0 ]; then
    error "Exiting installer"
    unset IFS;
    exit 1
fi
test_installed wget
if [ $? -ne 0 ]; then
    error "Failed to install required packages for later!"
    exit 1
fi

updateScript
if [ $? -ne 0 ]; then
    error "Failed to update script!"
    exit 1
fi

yellowMessage "NOTE: You can exit the script any time with CTRL+C"
yellowMessage "      but not at every point recommendable!"

test_installed curl tar screen
if [ $? -ne 0 ]; then
    error "Failed to install required packages for later!"
    exit 1
fi


info "Getting versions info"
TEASPEAK_VERSION=$(curl -s --connect-timeout 60 -S -k https://repo.teaspeak.de/latest)
REQUEST_URL="https://repo.teaspeak.de/server/linux/x64/TeaSpeak-${TEASPEAK_VERSION}.tar.gz"
if [ $? -ne 0 ]; then
    error "Failed to load the latest TeaSpeak version!"
    exit 1
fi

#FIXME this part!
# Update system and install TeaSpeak packages.
cyanMessage " "
cyanMessage "Update the system packages to the latest version?"
cyanMessage "*It is recommended to update the system, otherwise dependencies might brake!"
OPTIONS=("Update" "Skip" "Quit")
select OPTION in "${OPTIONS[@]}"; do
    case "$REPLY" in
        1|2 ) break;;
        3 ) option_quit_installer;;
        *) invalidOption;continue;;
    esac
done

if [ "$OPTION" == "${OPTIONS[0]}" ]; then
    greenOkAnim "# Updating the system packages..."
    eval "${SUDO_PREFIX} ${PACKET_MANAGER_UPDATE}"
elif [ "$OPTION" == "Skip" ]; then
    yellowOkAnim "System update skiped."
fi

cyanMessage " "
greenOkAnim "# Installing necessary TeaSpeak packages..."
#TODO ask the user here?
test_installed ffmpeg

if ! [ SUPPORT_LIBAV ]; then
    cyanMessage " "
    redWarnAnim "WARNING: This distribution (${OS}) has no libav-tools in its repositories, please compile it yourself."
    redMessage "          The web client cannot be used without libav-tools!"
else
    test_installed libav-tools
fi

# Install youtube-dl.
cyanMessage " "
cyanMessage "Do you want to install youtube-dl?"
cyanMessage "*Required if you want to use the musicbot with youtube."
OPTIONS=("Install" "Skip" "Quit")
select OPTION in "${OPTIONS[@]}"; do
    case "$REPLY" in
        1|2 ) break;;
        3 ) option_quit_installer;;
        *) invalidOption;continue;;
    esac
done

if [ "$OPTION" == "Install" ]; then
    test_installed youtube-dl
elif [ "$OPTION" == "Skip" ]; then
    yellowOkAnim "Package youtube-dl skiped."
fi
greenOkAnim "DONE!"

# Create user, yes or no?
cyanMessage " "
cyanMessage "Do you want to create a TeaSpeak user?"
cyanMessage "*It is recommended to create a separated TeaSpeak user!"
OPTIONS=("Yes" "No" "Quit")
select OPTION in "${OPTIONS[@]}"; do
    case "$REPLY" in
        1|2 ) break;;
        3 ) option_quit_installer;;
        *) invalidOption;continue;;
    esac
done

if [ "$OPTION" == "Yes" ]; then
    cyanMessage " "
    cyanMessage "Please enter the name of the TeaSpeak user."
    read teaUser
    noUser=false
elif [ "$OPTION" == "No" ]; then
    yellowOkAnim "User creation skiped."
    noUser=true
fi

# TeaSpeak install path.
cyanMessage " "
cyanMessage "Please enter the TeaSpeak installation path."
cyanMessage "Empty input = /home/ | Example input = /srv/"
read teaPath
if [[ -z "$teaPath" ]]; then
    teaPath='home'
fi

#TODO moveout this to a extra function
# Key, password or disabled login.
if [ "$noUser" == "false" ]; then
    cyanMessage " "
    cyanMessage "Create key, set password or set no login?"

    OPTIONS=("Create key" "Set password" "No Login" "Quit")
    select OPTION in "${OPTIONS[@]}"; do
        case "$REPLY" in
            1|2|3 ) break;;
            4 ) option_quit_installer;;
            *) invalidOption;continue;;
        esac
    done

    if [ "$OPTION" == "Create key" ]; then
       if { command -v ssh-keygen; } >/dev/null 2>&1; then
            groupadd $teaUser
            mkdir -p /$teaPath
            useradd -m -b /$teaPath -s /bin/bash -g $teaUser $teaUser

            if [ -d /$teaPath/$teaUser/.ssh ]; then
                rm -rf /$teaPath/$teaUser/.ssh
            fi

            mkdir -p /$teaPath/$teaUser/.ssh
            chown $teaUser:$teaUser /$teaPath/$teaUser/.ssh
            cd /$teaPath/$teaUser/.ssh

            cyanMessage " "
            cyanMessage "It is recommended, but not required to set a password."
            su -c "ssh-keygen -t rsa" $teaUser

            KEYNAME=`find -maxdepth 1 -name "*.pub" | head -n 1`

            if [ "$KEYNAME" != "" ]; then
                su -c "cat $KEYNAME >> authorized_keys" $teaUser
            else
                redMessage "Could not find a key. You might need to create one manually at a later point."
            fi
        else
            errorExit "Can't find ssh-keygen to create a key!"
        fi
    elif [ "$OPTION" == "Set password" ]; then
        groupadd $teaUser
        mkdir -p /$teaPath
        useradd -m -b /$teaPath -s /bin/bash -g $teaUser $teaUser

        passwd $teaUser
    elif [ "$OPTION" == "No Login" ]; then
        groupadd $teaUser
        mkdir -p /$teaPath
        useradd -m -b /$teaPath -s /usr/sbin/nologin -g $teaUser $teaUser
    fi
fi
	
if [ "$noUser" == "false" ]; then
    cd /$teaPath/$teaUser/
else
    mkdir -p /$teaPath
    cd /$teaPath/
fi
	
# Downloading and setting up TeaSpeak.
cyanMessage " "
cyanMessage "Getting TeaSpeak version..."
greenOkAnim "# Newest version is ${TEASPEAK_VERSION}"

cyanMessage " "
greenOkAnim "# Downloading ${REQUEST_URL}"
curl --connect-timeout 60 -s -S "$REQUEST_URL" -o teaspeak_latest.tar.gz
if [ $? -ne 0 ]; then
    error "Failed to download the latest TeaSpeak version!"
    exit 1
fi
greenOkAnim "# Unpacking and removing .tar.gz"
tar -xzf teaspeak_latest.tar.gz
rm teaspeak_latest.tar.gz
greenOkAnim "DONE!"

cyanMessage " "
greenOkAnim "# Making scripts executable."
if [ "$noUser" == "false" ]; then
    chown -R $teaUser:$teaUser /$teaPath/$teaUser/*
    chmod 774 /$teaPath/$teaUser/*.sh
else
    chown -R root:root /$teaPath/*
    chmod 774 /$teaPath/*.sh
fi
greenOkAnim "DONE!"

cyanMessage " "
greenOkAnim "Finished, TeaSpeak ${TEASPEAK_VERSION} is now installed!"

# Start TeaSpeak in minimal mode.
cyanMessage " "
cyanMessage "Do you want to start TeaSpeak?"
cyanMessage "*Please save the Serverquery login and the Serveradmin token the first time you start TeaSpeak!"
cyanMessage "*CTRL+C = Exit"
OPTIONS=("Start server" "Finish and exit")
select OPTION in "${OPTIONS[@]}"; do
    case "$REPLY" in
        1|2 ) break;;
        *) invalidOption;continue;;
    esac
done
	
if [ "$OPTION" == "${OPTIONS[0]}" ]; then
    cyanMessage " "
    greenOkAnim "# Starting TeaSpeak..."
    if [ "$noUser" == "false" ]; then
        cd /$teaPath/$teaUser; LD_LIBRARY_PATH="$LD_LIBRARY_PATH;./libs/" ./TeaSpeakServer; stty cooked echo
    else
        cd /$teaPath; LD_LIBRARY_PATH="$LD_LIBRARY_PATH;./libs/" ./TeaSpeakServer && stty cooked echo
    fi
	
    cyanMessage " "
    greenOkAnim "# Making new created files executable."
    if [ "$noUser" == "false" ]; then
        chown -R $teaUser:$teaUser /$teaPath/$teaUser/*
        chmod 774 /$teaPath/$teaUser/*.sh
    else
        chown -R root:root /$teaPath/*
        chmod 774 /$teaPath/*.sh
    fi
    greenOkAnim "DONE!"
fi

cyanMessage " "

yellowMessage "NOTE: It is recommended to start the TeaSpeak server with the created user!"
yellowMessage "      to start the TeaSpeak you can use the following bash scripts:"
yellowMessage "      teastart.sh, teastart_minimal.sh, teastart_autorestart.sh and tealoop.sh."
greenOkAnim "Script successfully completed."

exit 0