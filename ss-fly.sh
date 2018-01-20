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
	if [[ "$#" -ne 1 ]]; then
		wrong_para_prompt "请输入密码"
		return 1
	fi
	echo "{
    \"server\":\"0.0.0.0\",
    \"server_port\":8388,
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
	ssserver -c /etc/shadowsocks.json -d start
	sed -i '$i\ssserver -c /etc/shadowsocks.json -d start'  /etc/rc.local
	echo '安装成功~尽情冲浪吧'
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
        install $2
		;;
	* )
		usage
		;;
esac
