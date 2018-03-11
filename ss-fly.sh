#! /bin/bash
# Copyright (c) 2018 flyzy2005

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
usage () {
	cat $DIR/sshelp
}

wrong_para_prompt() {
    echo "参数输入错误!$1"
}

install() {
	if [[ "$#" -lt 1 ]]
        then
          wrong_para_prompt "请输入至少一个参数作为密码"
	  return 1
	fi
        port="1024"
        if [[ "$#" -ge 2 ]]
        then
          port=$2
        fi
        if [[ $port -le 0 || $port -gt 65535 ]]
        then
          wrong_para_prompt "端口号输入格式错误，请输入1到65535"
          exit 1
        fi
	echo "{
    \"server\":\"0.0.0.0\",
    \"server_port\":$port,
    \"local_address\": \"127.0.0.1\",
    \"local_port\":1080,
    \"password\":\"$1\",
    \"timeout\":300,
    \"method\":\"aes-256-cfb\"
}" > /etc/shadowsocks.json
	apt-get update
	apt-get install -y python-pip
	pip install --upgrade pip
	pip install setuptools
	pip install shadowsocks
	chmod 755 /etc/shadowsocks.json
	apt-get install python-m2crypto
	ps -fe|grep ssserver |grep -v grep
        if [ $? -ne 0 ]
        then
          ssserver -c /etc/shadowsocks.json -d start
        else
          ssserver -c /etc/shadowsocks.json -d restart
        fi
	rclocal=`cat /etc/rc.local`
        if [[ $rclocal != *'ssserver -c /etc/shadowsocks.json -d start'* ]]
        then
          sed -i '$i\ssserver -c /etc/shadowsocks.json -d start'  /etc/rc.local
        fi
	echo '安装成功~尽情冲浪吧'
}

install_bbr() {
i=`uname -r | cut -f 2 -d .`
if [ $i -le 9 ]
then
    if
        echo '准备下载镜像文件...' && wget http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.10.2/linux-image-4.10.2-041002-generic_4.10.2-041002.201703120131_amd64.deb

    then
        echo '镜像文件下载成功，开始安装...' && dpkg -i linux-image-4.10.2-041002-generic_4.10.2-041002.201703120131_amd64.deb && update-grub && echo '镜像安装成功，准备重启...' && reboot
    else
        echo '下载内核文件失败，请重新执行安装BBR命令'
        exit 1
    fi
fi
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
result=`sysctl net.ipv4.tcp_available_congestion_control`
if [[ $result == *'bbr'* ]]
then
    echo 'BBR开启成功'
else 
    echo 'BBR开启失败，请重试'
fi
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
	echo '必需以root身份运行，请使用sudo命令'
	exit 1;
fi

case $1 in
	-i|i|install )
        install $2 $3
		;;
        -bbr )
        install_bbr
                ;;
	* )
		usage
		;;
esac
