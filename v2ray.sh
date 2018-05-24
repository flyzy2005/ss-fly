#! /bin/bash
# Copyright (c) 2018 flyzy小站

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

os='ossystem'

check_os() {
    if [[ -f /etc/redhat-release ]]; then
        os="centos"
    elif cat /etc/issue | grep -Eqi "debian"; then
        os="debian"
    elif cat /etc/issue | grep -Eqi "ubuntu"; then
        os="ubuntu"
    elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
        os="centos"
    elif cat /proc/version | grep -Eqi "debian"; then
        os="debian"
    elif cat /proc/version | grep -Eqi "ubuntu"; then
        os="ubuntu"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        os="centos"
    fi
}

getversion(){
    if [[ -s /etc/redhat-release ]]; then
        grep -oE  "[0-9.]+" /etc/redhat-release
    else
        grep -oE  "[0-9.]+" /etc/issue
    fi
}

centosversion(){
    if [ ${os} == 'centos' ]
    then
        local code=$1
        local version="$(getversion)"
        local main_ver=${version%%.*}
        if [ "$main_ver" == "$code" ]; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

firewall_set() {
	echo -e "[${green}信息${plain}] 正在设置防火墙..."
	if centosversion 6; then
		/etc/init.d/iptables status > /dev/null 2>&1
		if [ $? -eq 0 ]; then
			chkconfig iptables off
			echo -e "[${green}信息${plain}] 防火墙已经关闭。"
		else
			echo -e "[${yellow}警告${plain}] 防火墙（iptables）好像已经停止或没有安装，如有需要请手动关闭防火墙。"
		fi
	elif centosversion 7; then
		systemctl status firewalld > /dev/null 2>&1
		if [ $? -eq 0 ]; then
			systemctl stop firewalld.service
			systemctl disable firewalld.service
			echo -e "[${green}信息${plain}] 防火墙已经关闭。"
		else
			echo -e "[${yellow}警告${plain}] 防火墙（iptables）好像已经停止或没有安装，如有需要请手动关闭防火墙。"
		fi
	fi
	echo -e "[${green}信息${plain}] 防火墙设置成功。"
}

main() {
	check_os
	if [ ${os} == 'centos' ]
        then
                firewall_set
        fi
	bash <(curl -L -s https://install.direct/go.sh)	
}

if [ "$EUID" -ne 0 ]; then
	echo -e "[${red}错误${plain}] 必需以root身份运行，请使用sudo命令"
	exit 1;
fi

main
