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
                        'ubuntu')
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
	sysfile=`cat /etc/sysctl.conf`
	if [[ $sysfile != *'net.core.default_qdisc=fq'* ]]
	then
    		echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
	fi
	if [[ $sysfile != *'net.ipv4.tcp_congestion_control=bbr'* ]]
	then
    		echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
	fi
	sysctl -p > /dev/null
	i=`uname -r | cut -f 2 -d .`
	if [ $i -le 9 ]
	then
    		if
        	echo '准备下载镜像文件...' && wget http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.10.2/linux-image-4.10.2-041002-generic_4.10.2-041002.201703120131_amd64.deb
    		then
        		echo '镜像文件下载成功，开始安装...' && dpkg -i linux-image-4.10.2-041002-generic_4.10.2-041002.201703120131_amd64.deb && update-grub && echo '镜像安装成功，系统即将重启，重启后bbr将成功开启...' && reboot
    		else
        		echo '下载内核文件失败，请重新执行安装BBR命令'
        		exit 1
    		fi
	fi
	result=`sysctl net.ipv4.tcp_available_congestion_control`
	if [[ $result == *'bbr'* ]]
	then
    		echo 'BBR已开启成功'
	else 
    		echo 'BBR开启失败，请重试'
	fi
}

install_ssr() {
	wget --no-check-certificate https://raw.githubusercontent.com/teddysun/shadowsocks_install/master/shadowsocksR.sh
	chmod +x shadowsocksR.sh
	./shadowsocksR.sh 2>&1 | tee shadowsocksR.log
}

check_os() {
        source /etc/os-release
        case $ID in
                ubuntu)
                os='ubuntu'
                ;;
                centos)
                os='centos'
                ;;
                *)
                echo -e "[${red}错误${plain}] 本脚本暂时只支持Centos和Ubuntu系统，如需用本脚本，请先修改你的系统类型"
                exit 1
                ;;
        esac
}

check_dependency() {
        case $os in
                'ubuntu')
                apt-get -y update
                apt-get -y install python python-dev python-setuptools openssl libssl-dev curl wget unzip gcc automake autoconf make libtool
                ;;
                'centos')
                yum install -y python python-devel python-setuptools openssl openssl-devel curl wget unzip gcc automake autoconf make libtool
        esac
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
                        'ubuntu')
                                update-rc.d ss-fly defaults
                                ;;
                        'centos')
                                chkconfig -add ss-fly
                                shkconfig ss-fly on  
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
	* )
		usage
		;;
esac
