#!/bin/bash
# Check every module version pinned in nginx-autoinstall.sh against upstream.
# Sources checked: GitHub API (releases/tags) and nginx.org, matching the
# locations the installer downloads from.
#
# Usage: ./check-modules-updates.sh
#   GITHUB_TOKEN can be set to avoid the unauthenticated API rate limit (60/h).
#
# Exit codes: 0 = everything up to date, 1 = updates available, 2 = error

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
INSTALLER="$SCRIPT_DIR/nginx-autoinstall.sh"

if [[ ! -f $INSTALLER ]]; then
	echo "Error: nginx-autoinstall.sh not found next to this script" >&2
	exit 2
fi

CURL_ARGS=(-fsSL --max-time 30)
if [[ -n ${GITHUB_TOKEN:-} ]]; then
	API_AUTH=(-H "Authorization: Bearer $GITHUB_TOKEN")
else
	API_AUTH=()
fi

# Read the default value of a VERSION variable from the installer
current_version() {
	sed -n "s/^$1=\${$1:-\(.*\)}/\1/p" "$INSTALLER"
}

# Latest tag of a GitHub repo, pre-releases (rc/beta/alpha) excluded
github_latest_tag() {
	curl "${CURL_ARGS[@]}" "${API_AUTH[@]}" "https://api.github.com/repos/$1/tags?per_page=100" |
		grep -oP '"name":\s*"\K[^"]+' |
		grep -viE 'rc|beta|alpha|preview|build' |
		sed -e 's/^v//' -e "s/^${2:-}//" -e 's/-stable$//' |
		grep -E '^[0-9][0-9.]*(-[0-9]+)?$' | sort -V | tail -1
}

# Latest stable release of a GitHub repo via releases/latest
github_latest_release() {
	curl "${CURL_ARGS[@]}" "${API_AUTH[@]}" "https://api.github.com/repos/$1/releases/latest" |
		grep -oP '"tag_name":\s*"\K[^"]+' |
		sed -e 's/^v//' -e "s/^${2:-}//"
}

# Latest nginx version for a given branch parity (stable = even minor, mainline = odd)
nginx_latest() {
	local parity=$1
	curl "${CURL_ARGS[@]}" "https://nginx.org/download/" |
		grep -oP 'nginx-\K[0-9]+\.[0-9]+\.[0-9]+(?=\.tar\.gz")' |
		sort -uV |
		awk -F. -v p="$parity" '$2 % 2 == p' | tail -1
}


TOTAL=0
OUTDATED=0
ERRORS=0

printf '%-22s %-16s %-16s %s\n' "MODULE" "CURRENT" "LATEST" "STATUS"
printf '%-22s %-16s %-16s %s\n' "------" "-------" "------" "------"

check() {
	local name=$1 var=$2 latest=$3
	local current
	current=$(current_version "$var")
	TOTAL=$((TOTAL + 1))

	if [[ -z $current ]]; then
		printf '%-22s %-16s %-16s %s\n' "$name" "?" "${latest:-?}" "ERROR (var not found)"
		ERRORS=$((ERRORS + 1))
		return
	fi
	if [[ -z $latest ]]; then
		printf '%-22s %-16s %-16s %s\n' "$name" "$current" "?" "ERROR (upstream check failed)"
		ERRORS=$((ERRORS + 1))
		return
	fi
	if [[ $current == "$latest" ]]; then
		printf '%-22s %-16s %-16s %s\n' "$name" "$current" "$latest" "OK"
	else
		printf '%-22s %-16s %-16s %s\n' "$name" "$current" "$latest" "UPDATE AVAILABLE"
		OUTDATED=$((OUTDATED + 1))
	fi
}

check "nginx stable" NGINX_STABLE_VER "$(nginx_latest 0)"
check "nginx mainline" NGINX_MAINLINE_VER "$(nginx_latest 1)"
check "OpenSSL" OPENSSL_VER "$(github_latest_release openssl/openssl openssl-)"
check "LibreSSL" LIBRESSL_VER "$(github_latest_tag libressl/portable)"
check "PageSpeed" NPS_VER "$(github_latest_tag apache/incubator-pagespeed-ngx)"
check "Headers More" HEADERMOD_VER "$(github_latest_tag openresty/headers-more-nginx-module)"
check "libmaxminddb" LIBMAXMINDDB_VER "$(github_latest_release maxmind/libmaxminddb)"
check "ngx_http_geoip2" GEOIP2_VER "$(github_latest_tag leev/ngx_http_geoip2_module)"
check "LuaJIT2" LUA_JIT_VER "$(github_latest_tag openresty/luajit2)"
check "lua-nginx-module" LUA_NGINX_VER "$(github_latest_tag openresty/lua-nginx-module)"
check "lua-resty-core" LUA_RESTYCORE_VER "$(github_latest_tag openresty/lua-resty-core)"
check "lua-resty-lrucache" LUA_RESTYLRUCACHE_VER "$(github_latest_tag openresty/lua-resty-lrucache)"
check "ngx_devel_kit" NGINX_DEV_KIT "$(github_latest_tag vision5/ngx_devel_kit)"
check "ngx_http_redis" HTTPREDIS_VER "$(github_latest_tag osokin/ngx_http_redis)"
check "echo-nginx-module" NGXECHO_VER "$(github_latest_tag openresty/echo-nginx-module)"
check "zlib-ng" ZLIBNG_VER "$(github_latest_release zlib-ng/zlib-ng)"
check "PCRE2" PCRE2_VER "$(github_latest_release PCRE2Project/pcre2 pcre2-)"

echo ""
echo "$TOTAL modules checked: $OUTDATED update(s) available, $ERRORS check error(s)"

if [[ $ERRORS -gt 0 ]]; then
	exit 2
elif [[ $OUTDATED -gt 0 ]]; then
	exit 1
fi
exit 0
