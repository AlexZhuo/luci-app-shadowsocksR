TMP_DIR="/tmp/etc/update_gfw"
LIST_DIR="/etc/"
GFWLIST="/etc/gfwlist/china-banned"
GFWLIST_URL="https://raw.githubusercontent.com/AlexZhuo/BlockedDomains/master/china-banned"

mkdir -p $TMP_DIR

echo 'GFWList Updating...'
cp $GFWLIST $LIST_DIR/GFWList.backup

wget --no-check-certificate -q -P $TMP_DIR $GFWLIST_URL
[ -e $TMP_DIR/china-banned ] && cp $TMP_DIR/china-banned $GFWLIST && echo '	GFWList Updated. '|| echo '	Download GFWList Fail. '
rm -f $TMP_DIR/china-banned
echo ''
