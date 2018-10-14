#! /bin/bash
# Copyright (c) 2018 flyzy小站

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

os='ossystem'
password='flyzy2005.com'
port='1024'
libsodium_file="libsodium-1.0.16"
libsodium_url="https://github.com/jedisct1/libsodium/releases/download/1.0.16/libsodium-1.0.16.tar.gz"

fly_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

kernel_ubuntu_url="http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.10.2/linux-image-4.10.2-041002-generic_4.10.2-041002.201703120131_amd64.deb"
kernel_ubuntu_file="linux-image-4.10.2-041002-generic_4.10.2-041002.201703120131_amd64.deb"

usage () {
        cat $fly_dir/sshelp
}

DIR=`pwd`

wrong_para_prompt() {
    echo -e "[${red}错误${plain}] 参数输入错误!$1"
}

install_ss() {
        if [[ "$#" -lt 1 ]]
        then
          wrong_para_prompt "请输入至少一个参数作为密码"
          return 1
        fi
        password=$1
        if [[ "$#" -ge 2 ]]
        then
          port=$2
        fi
        if [[ $port -le 0 || $port -gt 65535 ]]
        then
          wrong_para_prompt "端口号输入格式错误，请输入1到65535"
          exit 1
        fi
        check_os
        check_dependency
        download_files
        ps -ef | grep -v grep | grep -i "ssserver" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
                ssserver -c /etc/shadowsocks.json -d stop
        fi
        generate_config $password $port
        if [ ${os} == 'centos' ]
        then
                firewall_set
        fi
        install
        cleanup
}

uninstall_ss() {
        read -p "确定要卸载ss吗？(y/n) :" option
        [ -z ${option} ] && option="n"
        if [ "${option}" == "y" ] || [ "${option}" == "Y" ]
        then
                ps -ef | grep -v grep | grep -i "ssserver" > /dev/null 2>&1
                if [ $? -eq 0 ]; then
                        ssserver -c /etc/shadowsocks.json -d stop
                fi
                case $os in
                        'ubuntu'|'debian')
                                update-rc.d -f ss-fly remove
                                ;;
                        'centos')
                                chkconfig --del ss-fly
                                ;;
                esac
                rm -f /etc/shadowsocks.json
                rm -f /var/run/shadowsocks.pid
                rm -f /var/log/shadowsocks.log
                if [ -f /usr/local/shadowsocks_install.log ]; then
                        cat /usr/local/shadowsocks_install.log | xargs rm -rf
                fi
                echo "ss卸载成功！"
        else
                echo
                echo "卸载取消"
        fi
}

install_bbr() {
	[[ -d "/proc/vz" ]] && echo -e "[${red}错误${plain}] 你的系统是OpenVZ架构的，不支持开启BBR。" && exit 1
	check_os
	check_bbr_status
	if [ $? -eq 0 ]
	then
		echo -e "[${green}提示${plain}] TCP BBR加速已经开启成功。"
		exit 0
	fi
	check_kernel_version
	if [ $? -eq 0 ]
	then
		echo -e "[${green}提示${plain}] 你的系统版本高于4.9，直接开启BBR加速。"
		sysctl_config
		echo -e "[${green}提示${plain}] TCP BBR加速开启成功"
		exit 0
	fi
	    
	if [[ x"${os}" == x"centos" ]]; then
        	install_elrepo
        	yum --enablerepo=elrepo-kernel -y install kernel-ml kernel-ml-devel
        	if [ $? -ne 0 ]; then
            		echo -e "[${red}错误${plain}] 安装内核失败，请自行检查。"
            		exit 1
        	fi
    	elif [[ x"${os}" == x"debian" || x"${os}" == x"ubuntu" ]]; then
        	[[ ! -e "/usr/bin/wget" ]] && apt-get -y update && apt-get -y install wget
        	#get_latest_version
        	#[ $? -ne 0 ] && echo -e "[${red}错误${plain}] 获取最新内核版本失败，请检查网络" && exit 1
       		 #wget -c -t3 -T60 -O ${deb_kernel_name} ${deb_kernel_url}
        	#if [ $? -ne 0 ]; then
            	#	echo -e "[${red}错误${plain}] 下载${deb_kernel_name}失败，请自行检查。"
            	#	exit 1
       		#fi
        	#dpkg -i ${deb_kernel_name}
        	#rm -fv ${deb_kernel_name}
		wget ${kernel_ubuntu_url}
		if [ $? -ne 0 ]
		then
			echo -e "[${red}错误${plain}] 下载内核失败，请自行检查。"
			exit 1
		fi
		dpkg -i ${kernel_ubuntu_file}
    	else
       	 	echo -e "[${red}错误${plain}] 脚本不支持该操作系统，请修改系统为CentOS/Debian/Ubuntu。"
        	exit 1
    	fi

    	install_config
    	sysctl_config
    	reboot_os
}

install_ssr() {
        check_os
        case $os in
                'ubuntu'|'debian')
		     apt-get -y update
                     apt-get -y install wget
                     ;;
                'centos')
                     yum install -y wget
                     ;;
        esac
	wget --no-check-certificate https://raw.githubusercontent.com/teddysun/shadowsocks_install/master/shadowsocksR.sh
	chmod +x shadowsocksR.sh
	./shadowsocksR.sh 2>&1 | tee shadowsocksR.log
}

check_os_() {
        source /etc/os-release
	local os_tmp=$(echo $ID | tr [A-Z] [a-z])
        case $os_tmp in
                ubuntu|debian)
                os='ubuntu'
                ;;
                centos)
                os='centos'
                ;;
                *)
                echo -e "[${red}错误${plain}] 本脚本暂时只支持Centos/Ubuntu/Debian系统，如需用本脚本，请先修改你的系统类型"
                exit 1
                ;;
        esac
}

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

check_bbr_status() {
    local param=$(sysctl net.ipv4.tcp_available_congestion_control | awk '{print $3}')
    if [[ x"${param}" == x"bbr" ]]; then
        return 0
    else
        return 1
    fi
}

version_ge(){
    test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" == "$1"
}

check_kernel_version() {
    local kernel_version=$(uname -r | cut -d- -f1)
    if version_ge ${kernel_version} 4.9; then
        return 0
    else
        return 1
    fi
}

sysctl_config() {
    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
    echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1
}

install_elrepo() {
    if centosversion 5; then
        echo -e "[${red}错误${plain}] 脚本不支持CentOS 5。"
        exit 1
    fi

    rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org

    if centosversion 6; then
        rpm -Uvh http://www.elrepo.org/elrepo-release-6-8.el6.elrepo.noarch.rpm
    elif centosversion 7; then
        rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-3.el7.elrepo.noarch.rpm
    fi

    if [ ! -f /etc/yum.repos.d/elrepo.repo ]; then
        echo -e "[${red}错误${plain}] 安装elrepo失败，请自行检查。"
        exit 1
    fi
}

get_latest_version() {

    latest_version=$(wget -qO- http://kernel.ubuntu.com/~kernel-ppa/mainline/ | awk -F'\"v' '/v[4-9]./{print $2}' | cut -d/ -f1 | grep -v -  | sort -V | tail -1)

    [ -z ${latest_version} ] && return 1

    if [[ `getconf WORD_BIT` == "32" && `getconf LONG_BIT` == "64" ]]; then
        deb_name=$(wget -qO- http://kernel.ubuntu.com/~kernel-ppa/mainline/v${latest_version}/ | grep "linux-image" | grep "generic" | awk -F'\">' '/amd64.deb/{print $2}' | cut -d'<' -f1 | head -1)
        deb_kernel_url="http://kernel.ubuntu.com/~kernel-ppa/mainline/v${latest_version}/${deb_name}"
        deb_kernel_name="linux-image-${latest_version}-amd64.deb"
    else
        deb_name=$(wget -qO- http://kernel.ubuntu.com/~kernel-ppa/mainline/v${latest_version}/ | grep "linux-image" | grep "generic" | awk -F'\">' '/i386.deb/{print $2}' | cut -d'<' -f1 | head -1)
        deb_kernel_url="http://kernel.ubuntu.com/~kernel-ppa/mainline/v${latest_version}/${deb_name}"
        deb_kernel_name="linux-image-${latest_version}-i386.deb"
    fi

    [ ! -z ${deb_name} ] && return 0 || return 1
}

get_opsy() {
    [ -f /etc/redhat-release ] && awk '{print ($1,$3~/^[0-9]/?$3:$4)}' /etc/redhat-release && return
    [ -f /etc/os-release ] && awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release && return
    [ -f /etc/lsb-release ] && awk -F'[="]+' '/DESCRIPTION/{print $2}' /etc/lsb-release && return
}

opsy=$( get_opsy )
arch=$( uname -m )
lbit=$( getconf LONG_BIT )
kern=$( uname -r )

check_dependency() {
        case $os in
                'ubuntu'|'debian')
                apt-get -y update
                apt-get -y install python python-dev python-setuptools openssl libssl-dev curl wget unzip gcc automake autoconf make libtool
                ;;
                'centos')
                yum install -y python python-devel python-setuptools openssl openssl-devel curl wget unzip gcc automake autoconf make libtool
        esac
}

install_config() {
    if [[ x"${os}" == x"centos" ]]; then
        if centosversion 6; then
            if [ ! -f "/boot/grub/grub.conf" ]; then
                echo -e "[${red}错误${plain}] 没有找到/boot/grub/grub.conf文件。"
                exit 1
            fi
            sed -i 's/^default=.*/default=0/g' /boot/grub/grub.conf
        elif centosversion 7; then
            if [ ! -f "/boot/grub2/grub.cfg" ]; then
                echo -e "[${red}错误${plain}] 没有找到/boot/grub2/grub.cfg文件。"
                exit 1
            fi
            grub2-set-default 0
        fi
    elif [[ x"${os}" == x"debian" || x"${os}" == x"ubuntu" ]]; then
        /usr/sbin/update-grub
    fi
}

reboot_os() {
    echo
    echo -e "[${green}提示${plain}] 系统需要重启BBR才能生效。"
    read -p "是否立马重启 [y/n]" is_reboot
    if [[ ${is_reboot} == "y" || ${is_reboot} == "Y" ]]; then
        reboot
    else
        echo -e "[${green}提示${plain}] 取消重启。其自行执行reboot命令。"
        exit 0
    fi
}

download_files() {
        if ! wget --no-check-certificate -O ${libsodium_file}.tar.gz ${libsodium_url}
        then
                echo -e "[${red}错误${plain}] 下载${libsodium_file}.tar.gz失败!"
                exit 1
        fi
        if ! wget --no-check-certificate -O shadowsocks-master.zip https://github.com/shadowsocks/shadowsocks/archive/master.zip
        then
                echo -e "[${red}错误${plain}] shadowsocks安装包文件下载失败！"
                exit 1
        fi
}

generate_config() {
    cat > /etc/shadowsocks.json<<-EOF
{
    "server":"0.0.0.0",
    "server_port":$2,
    "local_address":"127.0.0.1",
    "local_port":1080,
    "password":"$1",
    "timeout":300,
    "method":"aes-256-cfb",
    "fast_open":false
}
EOF
}

firewall_set(){
    echo -e "[${green}信息${plain}] 正在设置防火墙..."
    if centosversion 6; then
        /etc/init.d/iptables status > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            iptables -L -n | grep -i ${port} > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${port} -j ACCEPT
                iptables -I INPUT -m state --state NEW -m udp -p udp --dport ${port} -j ACCEPT
                /etc/init.d/iptables save
                /etc/init.d/iptables restart
            else
                echo -e "[${green}信息${plain}] port ${port}已经开放。"
            fi
        else
            echo -e "[${yellow}警告${plain}] 防火墙（iptables）好像已经停止或没有安装，如有需要请手动关闭防火墙。"
        fi
    elif centosversion 7; then
        systemctl status firewalld > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            firewall-cmd --permanent --zone=public --add-port=${port}/tcp
            firewall-cmd --permanent --zone=public --add-port=${port}/udp
            firewall-cmd --reload
        else
            echo -e "[${yellow}警告${plain}] 防火墙（iptables）好像已经停止或没有安装，如有需要请手动关闭防火墙。"
        fi
    fi
    echo -e "[${green}信息${plain}] 防火墙设置成功。"
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

getversion(){
    if [[ -s /etc/redhat-release ]]; then
        grep -oE  "[0-9.]+" /etc/redhat-release
    else
        grep -oE  "[0-9.]+" /etc/issue
    fi
}

install() {
        if [ ! -f /usr/lib/libsodium.a ]
        then 
                cd ${DIR}
                tar zxf ${libsodium_file}.tar.gz
                cd ${libsodium_file}
                ./configure --prefix=/usr && make && make install
                if [ $? -ne 0 ] 
                then 
                        echo -e "[${red}错误${plain}] libsodium安装失败!"
                        cleanup
                exit 1  
                fi
        fi      
        ldconfig
        
        cd ${DIR}
        unzip -q shadowsocks-master.zip
        if [ $? -ne 0 ]
        then 
                echo -e "[${red}错误${plain}] 解压缩失败，请检查unzip命令"
                cleanup
                exit 1
        fi      
        cd ${DIR}/shadowsocks-master
        python setup.py install --record /usr/local/shadowsocks_install.log
        if [ -f /usr/bin/ssserver ] || [ -f /usr/local/bin/ssserver ]
        then 
                cp $fly_dir/ss-fly /etc/init.d/
                chmod +x /etc/init.d/ss-fly
                case $os in
                        'ubuntu'|'debian')
                                update-rc.d ss-fly defaults
                                ;;
                        'centos')
                                chkconfig --add ss-fly
                                chkconfig ss-fly on
                                ;;
                esac            
                ssserver -c /etc/shadowsocks.json -d start
        else    
                echo -e "[${red}错误${plain}] ss服务器安装失败，请联系flyzy小站（https://www.flyzy2005.com）"
                cleanup
                exit 1
        fi      
        echo -e "[${green}成功${plain}] 安装成功尽情冲浪！"
        echo -e "你的服务器地址（IP）：\033[41;37m $(get_ip) \033[0m"
        echo -e "你的密码            ：\033[41;37m ${password} \033[0m"
        echo -e "你的端口            ：\033[41;37m ${port} \033[0m"
        echo -e "你的加密方式        ：\033[41;37m aes-256-cfb \033[0m"
        echo -e "欢迎访问flyzy小站   ：\033[41;37m https://www.flyzy2005.com \033[0m"
        get_ss_link
}

cleanup() {
        cd ${DIR}
        rm -rf shadowsocks-master.zip shadowsocks-master ${libsodium_file}.tar.gz ${libsodium_file}
}

get_ip(){
    local IP=$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipv4.icanhazip.com )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipinfo.io/ip )
    [ ! -z ${IP} ] && echo ${IP} || echo
}

get_ss_link(){
    if [ ! -f "/etc/shadowsocks.json" ]; then
        echo 'shdowsocks配置文件不存在，请检查（/etc/shadowsocks.json）'
        exit 1
    fi
    local tmp=$(echo -n "`get_config_value method`:`get_config_value password`@`get_ip`:`get_config_value server_port`" | base64 -w0)
    echo -e "你的ss链接：\033[41;37m ss://${tmp} \033[0m"
}

get_config_value(){
    cat /etc/shadowsocks.json | grep "\"$1\":"|awk -F ":" '{print $2}'| sed 's/\"//g;s/,//g;s/ //g'
}

if [ "$#" -eq 0 ]; then
	usage
	exit 0
fi

case $1 in
	-h|h|help )
		usage
		exit 0;
		;;
	-v|v|version )
		echo 'ss-fly Version 1.0, 2018-01-20, Copyright (c) 2018 flyzy2005'
		exit 0;
		;;
esac

if [ "$EUID" -ne 0 ]; then
	echo -e "[${red}错误${plain}] 必需以root身份运行，请使用sudo命令"
	exit 1;
fi

case $1 in
	-i|i|install )
        	install_ss $2 $3
		;;
        -bbr )
        	install_bbr
                ;;
        -ssr )
        	install_ssr
                ;;
	-uninstall )
		uninstall_ss
		;;
        -sslink )
                get_ss_link
                ;;
	* )
		usage
		;;
esac
