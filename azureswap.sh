######################################################################
## Config파일에서 해당 Key의 값을 얻어온다. 
# $1 = Config Path 
# $2 = key for change 
###################################################################### 
fGetConfigValue() {
  CONF_PATH=$1
  KEY_VALUE=$2

  #value=`cat $CONF_PATH | awk '/^'$KEY_VALUE'[   ][]/ { split($0, array, "[    ]*=[  ]*"); print $3;}'`
  value=`cat $CONF_PATH | awk -F = '/^'$KEY_VALUE'[\ \  ]*=/ { split($2, array,"#"); print array[1]; }'`

  echo $value

}


######################################################################
## Config파일에서 해당 Key의 값을 수정한다.
# $1 = Config Path
# $2 = key for change
# $3 = value for change
######################################################################

fSetConfigValue() {
  CONF_PATH=$1
  KEY_VALUE=$2
  SET_VALUE=$3

  touch $CONF_PATH.tmp
  chmod 664 $CONF_PATH.tmp

  value=$(fGetConfigValue $CONF_PATH $KEY_VALUE)

  cat $CONF_PATH | sed -e 's/^'$KEY_VALUE'[\ \ ]*=[\ \  ]*'$value'/'$KEY_VALUE'='$SET_VALUE'/g' > $CONF_PATH.tmp

  if [ -s $CONF_PATH.tmp ]
  then
    mv $CONF_PATH.tmp $CONF_PATH
  fi

}

fSetConfigValue /etc/waagent.conf ResourceDisk.Format y

fSetConfigValue /etc/waagent.conf ResourceDisk.EnableSwap y

fSetConfigValue /etc/waagent.conf ResourceDisk.SwapSizeMB 8192
