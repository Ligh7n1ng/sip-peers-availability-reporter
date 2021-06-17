#!/bin/bash

CertLoc="$1"
Email="$2"
SSHUser="$3"
SSHServerIP="$4"
LOffice="$5"

CurDate=$(date +%F)
CurTime=$(date +%H-%M-%S)

ssh -i "$CertLoc" $SSHUser@$SSHServerIP "sudo asterisk -rx 'sip show peers'" | sed '1d' | sed '$d' | awk '{print $1}' | awk 'BEGIN {FS="/"} {print $1}' > ./.peer_list.tmp

NumOfRec=$(wc -l < ./.peer_list.tmp)

if [ $NumOfRec -gt 0 ]
then
    echo -e "Address,SIP extension number,Status" >> ./$CurDate-$CurTime-sip.csv
    
    for (( i=1; i <= $NumOfRec; i++ ))
    do
         ProcPeer=$(cat "./.peer_list.tmp" | head -n $i | tail -n 1 | head -n 1)
         echo -e "Checking availability of SIP peer $ProcPeer... ($i/$NumOfRec)"
         SIPAddr=$(ssh -i "$CertLoc" $SSHUser@$SSHServerIP "sudo asterisk -rx 'sip show peer $ProcPeer'" | grep -E 'Name |Addr|Callerid|Status' | tr '\n' ' ' | tr -s ' ' | awk 'BEGIN {FS="\""} {print $2}')
         SIPNum=$(ssh -i "$CertLoc" $SSHUser@$SSHServerIP "sudo asterisk -rx 'sip show peer $ProcPeer'" | grep -E 'Name |Addr|Callerid|Status' | tr '\n' ' ' | tr -s ' ' | awk 'BEGIN{FS=":"}{print $2}'| awk '{print $1}')
         SIPStat=$(ssh -i "$CertLoc" $SSHUser@$SSHServerIP "sudo asterisk -rx 'sip show peer $ProcPeer'" | grep -E 'Name |Addr|Callerid|Status' | tr '\n' ';' | tr -s ' ' | awk 'BEGIN{FS=";"}{print $4}' | awk '{print $3}')
         echo -e "$SIPAddr,$SIPNum,$SIPStat" >> ./$CurDate-$CurTime-sip.csv
         SIPStatOld=$(grep ,$SIPNum, ./old-sip.csv | awk 'BEGIN{FS=","; OFS=","} {print $3}')
         if [ "$SIPStat" != "$SIPStatOld" ]
         then
            if [ "$SIPStat" = "OK" ]
            then
                echo -e "$SIPAddr,$SIPNum,Become available" >> ./$CurDate-$CurTime-avail-sip.csv
            else
                echo -e "$SIPAddr,$SIPNum,Become unavailable" >> ./$CurDate-$CurTime-unavail-sip.csv
            fi
         fi   
    done
    
    sed -i 's/OK/Available/g' ./$CurDate-$CurTime-sip.csv
    sed -i 's/UNKNOWN/Unavailable/g' ./$CurDate-$CurTime-sip.csv
    
    NumOfWorking=$(grep 'Available' ./$CurDate-$CurTime-sip.csv | wc -l)
    NumOfMalfunc=$(grep 'Unavailable' ./$CurDate-$CurTime-sip.csv | wc -l)
    
    echo -e ",,\nOverall available:,$NumOfWorking\nOverall unavailable:,$NumOfMalfunc" >> ./$CurDate-$CurTime-sip.csv
    
    $LOffice --infilter="Text CSV:44,34,UTF8"  --convert-to "xlsx:Calc MS Excel 2007 XML:UTF8" --outdir ./ ./$CurDate-$CurTime-sip.csv
    $LOffice --infilter="Text CSV:44,34,UTF8"  --convert-to "xlsx:Calc MS Excel 2007 XML:UTF8" --outdir ./ ./$CurDate-$CurTime-avail-sip.csv
    $LOffice --infilter="Text CSV:44,34,UTF8"  --convert-to "xlsx:Calc MS Excel 2007 XML:UTF8" --outdir ./ ./$CurDate-$CurTime-unavail-sip.csv
    
    ListOfAttach=$(ls *.xlsx)
    
    echo -e "Attached file contains list of available and unavailable SIP peers.\n\n=========================================\nThis letter is auto-generated.\nPlease do not reply :)\n=========================================" | mutt -s "SIP peers report" $Email -a $ListOfAttach
    
    
    rm -f "./.peer_list.tmp"
    rm -f "./old-sip.csv"
    mv  "./$CurDate-$CurTime-sip.csv" "./old-sip.csv"
    
    sed -i 's/Available/OK/g' ./old-sip.csv
    sed -i 's/Unavailable/UNKNOWN/g' ./old-sip.csv
    
    rm -f "./$CurDate-$CurTime-unavail-sip.csv"
    rm -f "./$CurDate-$CurTime-avail-sip.csv"
    rm -f *.xlsx
    
else
    echo "No SIP peers. Nothing to do."
fi

exit
