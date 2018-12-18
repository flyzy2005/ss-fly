一键脚本安装shadowsocks/shadowsocksR/V2Ray + 开启bbr
---

一键脚本搭建shadowsocks/shadowsocksR/V2Ray + 设置开启自启动 + 升级内核&开启bbr加速。

## 教程如何访问
因为这个脚本，[flyzy小站](https://www.flyzy2005.com)已经被GFW拉入黑名单了，直接DNS污染了，国内无法访问。

如果有翻墙方法，自然可以直接访问（目前flyzy2005.com已加入GFWList）。如果还在墙内，可以参考[flyzy小站最新访问方式与镜像网站地址](https://flyzyblog.com/way-to-flyzy2005/)访问教程，科学上网吧！

## 支持系统
CentOS 6+

Debian 7+

Ubuntu 12+

## 使用教程
一键搭建ss/ssr：[一键脚本搭建shadowsocks+开启bbr](https://www.flyzy2005.com/fan-qiang/shadowsocks/install-shadowsocks-in-one-command/)

一键搭建V2Ray：[一键脚本搭建V2Ray+配置与优化](https://www.flyzy2005.com/v2ray/how-to-build-v2ray/)

或者参考：[Wiki](https://github.com/flyzy2005/ss-fly/wiki)

## 推荐的VPS
[Vultr优惠网](https://www.vultryhw.com/)

[搬瓦工优惠网](https://www.bwgyhw.com/)

## 交流群
flyzy小站交流群：http://t.me/flyzyxiaozhan

搬瓦工用户交流群：https://t.me/banwagongusers

yum -y install git
git clone https://github.com/flyzy2005/ss-fly
ss-fly/ss-fly.sh -ssr
打开BBR
wget -N --no-check-certificate https://github.com/teddysun/across/raw/master/bbr.sh && chmod +x bbr.sh && bash bbr.sh
判断打开BBR成功
sysctl net.ipv4.tcp_available_congestion_control
显示
net.ipv4.tcp_available_congestion_control = bbr cubic reno 
里面有bbr就行了
启动：/etc/init.d/shadowsocks start
停止：/etc/init.d/shadowsocks stop
重启：/etc/init.d/shadowsocks restart
状态：/etc/init.d/shadowsocks status
配置文件路径：/etc/shadowsocks.json
日志文件路径：/var/log/shadowsocks.log
代码安装目录：/usr/local/shadowsocks
