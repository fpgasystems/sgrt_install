#!/bin/bash

bold=$(tput bold)
normal=$(tput sgr0)

chmod_x() {
    path="$1"
    for file in "$path"/*.sh; do
        chmod +x "$file"
        mv "$file" "${file%.sh}"
    done
}

#constants
CLI_NAME="sgutil"
TMP_PATH="/tmp"

#default constants
SGRT_BASE_PATH="/opt" #/opt/sgrt
MPICH_PATH="/opt/mpich"
MY_DRIVERS_PATH="/local/home/\$USER"
MY_PROJECTS_PATH="/home/\$USER/sgrt_projects"
ROCM_PATH="/opt/rocm"
VIVADO_DEVICES_MAX="1"
XILINX_PLATFORMS_PATH="/opt/xilinx/platforms"
XILINX_TOOLS_PATH="/tools/Xilinx"
XILINXD_LICENSE_FILE="2100@my-license-server.ethz.ch:2101@my-license-server.ethz.ch" # 2100@sgv-license-01.ethz.ch:2101@sgv-license-01.ethz.ch
XRT_PATH="/opt/xilinx/xrt"

#check if the user has sudo capabilities
if ! sudo -n true 2>/dev/null; then
    echo ""
    echo "The installation process requires sudo capabilities."
    echo ""
    exit 1
fi

#get hostname
url="${HOSTNAME}"
hostname="${url%%.*}"

echo ""
echo "${bold}sgrt_install${normal}"

#get sgrt_base_path
echo ""
echo -n "${bold}Please, enter a non-existing installation path (default: $SGRT_BASE_PATH):${normal} "
while true; do
    read -p "" sgrt_base_path
    #assign to default if empty
    if [ -z "$sgrt_base_path" ]; then
        sgrt_base_path=$SGRT_BASE_PATH
    fi
    #the installation destination should not exist
    if [ -d "$sgrt_base_path/sgrt" ]; then
        echo ""
        echo "Please, enter a non-existing installation path"
        #echo ""
    else
        echo ""
        echo "SGRT will be installed in ${bold}$sgrt_base_path/sgrt${normal}"
        break
    fi
done

#derive cli_path
cli_path=$sgrt_base_path/sgrt/cli #$sgrt_base_path/cli

#set VIRTUALIZED_SERVERS_LIST
echo ""
echo "${bold}Is $hostname a virtualized server (y/n)?:${normal}"
virtualized_server=""
while true; do
    read -p "" yn
    case $yn in
        "y")
            virtualized_server=$hostname
            break
            ;;
        "n")
            break
            ;;
    esac
done

#set ACAP_SERVERS_LIST
echo ""
echo "${bold}Does $hostname have any ACAP mounted on it (y/n)?:${normal}" 
acap_server=""
while true; do
    read -p "" yn
    case $yn in
        "y") 
            acap_server=$hostname
            break
            ;;
        "n")
            break
            ;;
    esac
done

#set FPGA_SERVERS_LIST
echo ""
echo "${bold}Does $hostname have any FPGA mounted on it (y/n)?:${normal}" 
fpga_server=""
while true; do
    read -p "" yn
    case $yn in
        "y") 
            fpga_server=$hostname
            break
            ;;
        "n")
            break
            ;;
    esac
done

#set GPU_SERVERS_LIST
echo ""
echo "${bold}Does $hostname have any GPU mounted on it (y/n)?:${normal}" 
gpu_server=""
while true; do
    read -p "" yn
    case $yn in
        "y") 
            gpu_server=$hostname
            break
            ;;
        "n")
            break
            ;;
    esac
done

#set CPU_SERVERS_LIST (the server does not have any ACAP, FPGA, or GPU)
cpu_server=""
if [ "$acap_server" = "" ] && [ "$fpga_server" = "" ] && [ "$gpu_server" = "" ]; then
    cpu_server=$hostname
fi

#get mpich_path
echo ""
read -p "${bold}Please, enter the value for MPICH_PATH (default: $MPICH_PATH):${normal} " mpich_path
if [ -z "$mpich_path" ]; then
    mpich_path=$MPICH_PATH
    echo $mpich_path
fi

#get my_drivers_path
echo ""
read -p "${bold}Please, enter the value for MY_DRIVERS_PATH (default: $MY_DRIVERS_PATH):${normal} " my_drivers_path
if [ -z "$my_drivers_path" ]; then
    my_drivers_path=$MY_DRIVERS_PATH
    echo $my_drivers_path
fi

#get my_projects_path
echo ""
read -p "${bold}Please, enter the value for MY_PROJECTS_PATH (default: $MY_PROJECTS_PATH):${normal} " my_projects_path
if [ -z "$my_projects_path" ]; then
    my_projects_path=$MY_PROJECTS_PATH
    echo $my_projects_path
fi

#get rocm_path
rocm_path=""
if [ "$gpu_server" = "$hostname" ]; then
    echo ""
    read -p "${bold}Please, enter the value for ROCM_PATH (default: $ROCM_PATH):${normal} " rocm_path
    if [ -z "$rocm_path" ]; then
        rocm_path=$ROCM_PATH
        echo $rocm_path
    fi
fi

#get xilinx_platforms_path
xilinx_platforms_path=""
xilinx_tools_path=""
xrt_path=""
if [ "$acap_server" = "$hostname" ] || [ "$fpga_server" = "$hostname" ]; then
    echo ""
    read -p "${bold}Please, enter the value for XILINX_PLATFORMS_PATH (default: $XILINX_PLATFORMS_PATH):${normal} " xilinx_platforms_path
    if [ -z "$xilinx_platforms_path" ]; then
        xilinx_platforms_path=$XILINX_PLATFORMS_PATH
        echo $xilinx_platforms_path
    fi

    #get xilinx_tools_path
    echo ""
    read -p "${bold}Please, enter the value for XILINX_TOOLS_PATH (default: $XILINX_TOOLS_PATH):${normal} " xilinx_tools_path
    if [ -z "$xilinx_tools_path" ]; then
        xilinx_tools_path=$XILINX_TOOLS_PATH
        echo $xilinx_tools_path
    fi

    #get xilinxd_license_file
    echo ""
    echo -n "${bold}Please, enter the value for XILINXD_LICENSE_FILE (example: $XILINXD_LICENSE_FILE):${normal} "
    while true; do
        read -p "" xilinxd_license_file
        #check if not empty
        if [ -z "$xilinxd_license_file" ]; then
            echo ""
            echo "Please, enter a valid value for XILINXD_LICENSE_FILE"
        else
            # Validate format
            if [[ "$xilinxd_license_file" =~ ^[[:digit:]]+@[[:alnum:].-]+(:[[:digit:]]+@[[:alnum:].-]+)?$ ]]; then
                # Valid format
                break
            else
                echo ""
                echo "Please, enter a valid value for XILINXD_LICENSE_FILE" 
            fi
        fi
    done

    #get xrt_path
    echo ""
    read -p "${bold}Please, enter the value for XRT_PATH (default: $XRT_PATH):${normal} " xrt_path
    if [ -z "$xrt_path" ]; then
        xrt_path=$XRT_PATH
        echo $xrt_path
    fi
fi

#define temporal installation path
SGRT_INSTALL_TMP_PATH=$TMP_PATH/sgrt_install

if [ ! -d "$SGRT_INSTALL_TMP_PATH" ]; then
    mkdir -p "$SGRT_INSTALL_TMP_PATH"
else
    echo ""
    echo "The directory ${bold}SGRT_INSTALL_TMP_PATH${normal} is already existing. Please, remove it and try again!"
    echo ""
    exit
fi

#checkout sgrt
echo ""
git clone https://github.com/fpgasystems/sgrt.git $SGRT_INSTALL_TMP_PATH/sgrt

#sgrt cleanup
rm $SGRT_INSTALL_TMP_PATH/sgrt/*.md
rm $SGRT_INSTALL_TMP_PATH/sgrt/*.png
rm $SGRT_INSTALL_TMP_PATH/sgrt/LICENSE
#docs
rm -rf $SGRT_INSTALL_TMP_PATH/sgrt/docs
#examples
rm -rf $SGRT_INSTALL_TMP_PATH/sgrt/examples
#playbooks
rm -rf $SGRT_INSTALL_TMP_PATH/sgrt/playbooks
#trash
if [ -d "$SGRT_INSTALL_TMP_PATH/sgrt/trash" ]; then
    rm -rf $SGRT_INSTALL_TMP_PATH/sgrt/trash
fi
#sgrt/api docs
rm $SGRT_INSTALL_TMP_PATH/sgrt/api/*.md
rm -rf $SGRT_INSTALL_TMP_PATH/sgrt/api/manual
#sgrt/cli docs
rm $SGRT_INSTALL_TMP_PATH/sgrt/cli/*.md
rm -rf $SGRT_INSTALL_TMP_PATH/sgrt/cli/manual

#manage scripts
chmod_x $SGRT_INSTALL_TMP_PATH/sgrt/cli
chmod_x $SGRT_INSTALL_TMP_PATH/sgrt/cli/build
chmod_x $SGRT_INSTALL_TMP_PATH/sgrt/cli/common
chmod_x $SGRT_INSTALL_TMP_PATH/sgrt/cli/enable
chmod_x $SGRT_INSTALL_TMP_PATH/sgrt/cli/get
chmod_x $SGRT_INSTALL_TMP_PATH/sgrt/cli/new
chmod_x $SGRT_INSTALL_TMP_PATH/sgrt/cli/program
chmod_x $SGRT_INSTALL_TMP_PATH/sgrt/cli/run
chmod_x $SGRT_INSTALL_TMP_PATH/sgrt/cli/set
chmod_x $SGRT_INSTALL_TMP_PATH/sgrt/cli/validate

#fill up server lists
echo -n "$virtualized_server" > "$SGRT_INSTALL_TMP_PATH/sgrt/cli/constants/VIRTUALIZED_SERVERS_LIST"
echo -n "$cpu_server" > "$SGRT_INSTALL_TMP_PATH/sgrt/cli/constants/CPU_SERVERS_LIST"
echo -n "$acap_server" > "$SGRT_INSTALL_TMP_PATH/sgrt/cli/constants/ACAP_SERVERS_LIST"
echo -n "$fpga_server" > "$SGRT_INSTALL_TMP_PATH/sgrt/cli/constants/FPGA_SERVERS_LIST"
echo -n "$gpu_server" > "$SGRT_INSTALL_TMP_PATH/sgrt/cli/constants/GPU_SERVERS_LIST"

#fill up paths
echo -n "$mpich_path" > "$SGRT_INSTALL_TMP_PATH/sgrt/cli/constants/MPICH_PATH"
echo -n "$my_drivers_path" > "$SGRT_INSTALL_TMP_PATH/sgrt/cli/constants/MY_DRIVERS_PATH"
echo -n "$my_projects_path" > "$SGRT_INSTALL_TMP_PATH/sgrt/cli/constants/MY_PROJECTS_PATH"
echo -n "$rocm_path" > "$SGRT_INSTALL_TMP_PATH/sgrt/cli/constants/ROCM_PATH"
echo -n "$VIVADO_DEVICES_MAX" > "$SGRT_INSTALL_TMP_PATH/sgrt/cli/constants/VIVADO_DEVICES_MAX" #it is fixed for now
echo -n "$xilinx_platforms_path" > "$SGRT_INSTALL_TMP_PATH/sgrt/cli/constants/XILINX_PLATFORMS_PATH"
echo -n "$xilinx_tools_path" > "$SGRT_INSTALL_TMP_PATH/sgrt/cli/constants/XILINX_TOOLS_PATH"
echo -n "$xrt_path" > "$SGRT_INSTALL_TMP_PATH/sgrt/cli/constants/XRT_PATH"

#create XILINXD_LICENSE_FILE
IFS=':' read -ra licenses <<< "$xilinxd_license_file"
for license in "${licenses[@]}"; do
    echo "$license" >> "$SGRT_INSTALL_TMP_PATH/sgrt/cli/constants/XILINXD_LICENSE_FILE"
done

#copy to sgrt_base_path
sudo mv $SGRT_INSTALL_TMP_PATH/sgrt $sgrt_base_path
sudo chown -R root:root $sgrt_base_path/sgrt

#adding to profile.d (system-wide $PATH)
echo "export PATH=\"$PATH:$cli_path\"" | sudo tee /etc/profile.d/"$CLI_NAME.sh" >/dev/null

#copying sgutil_completion
sudo mv $cli_path/$CLI_NAME"_completion" /usr/share/bash-completion/completions/$CLI_NAME
sudo chown root:root /usr/share/bash-completion/completions/$CLI_NAME

#remove folder
rm -rf $SGRT_INSTALL_TMP_PATH/sgrt

#print
echo ""
echo "${bold}$CLI_NAME was installed in $sgrt_base_path/sgrt!${normal}"
echo ""