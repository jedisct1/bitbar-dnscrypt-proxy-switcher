#!/usr/bin/env ksh
#
# dnscrypt-proxy switcher
#
# <bitbar.author.github>jedisct1</bitbar.author.github>
# <bitbar.author>Frank Denis</bitbar.author>
# <bitbar.desc>Toggle dnscrypt-proxy usage</bitbar.desc>
# <bitbar.image>https://raw.githubusercontent.com/jedisct1/bitbar-dnscrypt-proxy-switcher/master/bitbar-dnscrypt-proxy.jpg</bitbar.image>
# <bitbar.title>dnscrypt-proxy switcher</bitbar.title>
# <bitbar.url>https://github.com/jedisct1/bitbar-dnscrypt-proxy-switcher</bitbar.url>
# <bitbar.version>v0.1</bitbar.version>

DNSCRYPT_PROXY_IPS="127.0.0.1"
ADDITIONAL_IPS="9.9.9.9"
ADDITIONAL_NAME="quad9"

get_current_service() {
	services=$(networksetup -listnetworkserviceorder | fgrep 'Hardware Port')
	echo "$services" | while read line; do
		sname=$(echo $line | awk -F "(, )|(: )|[)]" '{print $2}')
		sdev=$(echo $line | awk -F "(, )|(: )|[)]" '{print $4}')
		if [ -n "$sdev" ]; then
			ifout="$(ifconfig $sdev 2>/dev/null)"
			echo "$ifout" | grep 'status: active' >/dev/null 2>&1
			if [ "$?" -eq 0 ]; then
				currentservice="$sname"
				break
			fi
		fi
	done

	if [ -n "$currentservice" ]; then
		echo $currentservice
	else
		exit 1
	fi
}

get_service_resolvers() {
	service="$1"
	ips=""
	for ip in $(networksetup -getdnsservers "$service" | sort -u); do
		if [ "$ips" ]; then
			ips="$ips "
		fi
		ips="$ips$ip"
	done
	echo "$ips"
}

get_current_resolvers() {
	[ -r /etc/resolv.conf ] || exit 0
	ips_i=""
	sort -u /etc/resolv.conf | while read line; do
		case "$line" in
		nameserver\ *)
			ip=$(echo "$line" | sed -e 's/nameserver *//' -e 's/ *//')
			ips_i="$ips_i $ip"
			;;
		esac
	done

	typeset -A found
	ips=""
	for ip_i in $ips_i; do
		if [ ! ${found["$ip_i"]} ]; then
			if [ "$ips" ]; then
				ips="$ips "
			fi
			ips="$ips$ip_i"
			found["$ip_i"]=1
		fi
	done

	echo "$ips"
}

display_name_for_resolvers() {
	resolvers="$1"
	if [ "$resolvers" = "$DNSCRYPT_PROXY_IPS" ]; then
		echo "dnscrypt-proxy"
	elif [ "$resolvers" = "${DNSCRYPT_PROXY_IPS} ${ADDITIONAL_IPS}" ]; then
		echo "dnscrypt-proxy + ${ADDITIONAL_NAME}"
	elif [ "$resolvers" = "" ]; then
		echo "none"
	else
		echo "$resolvers"
	fi
}

service=$(get_current_service)
if [ -z "$service" ]; then
	echo '🧟'
	exit 0
fi

service_resolvers=$(get_service_resolvers "$service")
current_resolvers=$(get_current_resolvers)
service_resolvers_name=$(display_name_for_resolvers "$service_resolvers")
current_resolvers_name=$(display_name_for_resolvers "$current_resolvers")

if [ "$#" -gt 0 ]; then
	wanted_resolvers="$*"
	networksetup -setdnsservers "$service" $wanted_resolvers
	dscacheutil -flushcache 2>/dev/null
	killall -HUP mDNSResponder 2>/dev/null
fi

if [ "$current_resolvers_name" = "dnscrypt-proxy" ]; then
	echo '🔒'
elif [ "$current_resolvers_name" = "dnscrypt-proxy + ${ADDITIONAL_NAME}" ]; then
	echo '🔓'
else
	echo '🤷'
fi
echo "---"

echo "${service} resolvers: ${service_resolvers_name}"
if [ "$service_resolvers_name" != "$current_resolvers_name" ]; then
	echo "Current resolvers: ${current_resolvers_name} | color=red"
fi

echo "Use default DNS | terminal=false refresh=true bash=\"${0}\" param1=empty"
echo "Use dnscrypt-proxy | terminal=false refresh=true bash=\"${0}\" param1='${DNSCRYPT_PROXY_IPS}'"
echo "Use dnscrypt-proxy + ${ADDITIONAL_NAME} | terminal=false refresh=true bash=\"${0}\" param1='${DNSCRYPT_PROXY_IPS} ${ADDITIONAL_IPS}'"
echo "View the dnscrypt-proxy public servers list | href=https://dnscrypt.info/public-servers"
