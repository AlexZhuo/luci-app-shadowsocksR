TMP_DIR="/tmp/etc/update_gfw"
LIST_DIR="/etc/"
CHINAROUTE_SSR="/etc/ipset/china"
CHINAROUTE_SS="/etc/china_route"
CHINAROUTE_URL="https://raw.githubusercontent.com/AlexZhuo/BlockedDomains/master/china_route"

mkdir -p $TMP_DIR

echo 'ChinaRoute Updating...'
cp $CHINAROUTE_SSR $LIST_DIR/ChinaRoute.backup

wget --no-check-certificate -q -P $TMP_DIR $CHINAROUTE_URL
[ -e $TMP_DIR/china_route ] && cp $TMP_DIR/china_route $CHINAROUTE_SS && echo '	ChinaRoute Updated. '|| echo '	Download CHINAROUTE Fail. '
echo create china hash:net family inet hashsize 1024 maxelem 65536 > $CHINAROUTE_SSR
awk -vs="" '{printf("add china %s\n",$0)}' $CHINAROUTE_SS >> $CHINAROUTE_SSR
rm -f $TMP_DIR/china_route
echo 'done'