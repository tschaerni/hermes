#---------------------------| Chat Commands |---------------------------------------------

#Example Command
#In the command system, $1 = Playername , $2 = parameter 1 , $3 = parameter 2 , ect
#e.g if Titansmasher types "!FOLD 9 8 7" then $1 = Titansmasher , $2 = 9 , $3 = 8 , $4 = 7
#function COMMAND_EXAMPLE(){
##Description told to user when !HELP EXAMPLE is used (This line must be a comment)
##USAGE: How to use the commands parameters (This line must be a comment)
#	if [ "$#" -ne "NumberOfParameters+1" ]
#	then
#		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 ParameterErrorMessage\n'"
#	else
#		Function workings
#	fi
#}


#Bank Commands
function COMMAND_DEPOSIT(){ 
#Deposits money into your server account from your player
#USAGE: !DEPOSIT <Amount>
	if [ "$#" -ne "2" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !DEPOSIT <Amount>\n'"
	else
# Check to make sure a posistive amount was entered
		if ! test "$2" -gt 0 2> /dev/null
		then
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALACTIC BANK - You must put in a positive number\n'"
		else 
# Run playerinfo command to update playerfile and get the current player credits
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALACTICE BANK - Connecting to servers\n'"
			log_playerinfo $1
#			as_user "screen -p 0 -S $SCREENID -X stuff $'/player_info $1\n'"
#			echo "sent message to counsel, now sleeping"
# Sleep is added here to give the console a little bit to respond

# Check the playerfile to see if it was updated recently by comparing it to the current time
			CURRENTTIME=$(date +%s)
#			echo "Current time $CURRENTTIME"
			OLDTIME=$(grep PlayerLastUpdate $PLAYERFILE/$1 | cut -d= -f2- |  tr -d ' ')
#			echo "Old time from playerfile $OLDTIME"
			ADJUSTEDTIME=$(( $CURRENTTIME - 10 ))
#			echo "Adjusted time to remove 10 seconds $ADJUSTEDTIME"
			if [ "$OLDTIME" -ge "$ADJUSTEDTIME" ]
			then
				BALANCECREDITS=$(grep CreditsInBank $PLAYERFILE/$1 | cut -d= -f2- |  tr -d ' ')
#				echo $BALANCECREDITS
				CREDITSTOTAL=$(grep CurrentCredits $PLAYERFILE/$1 | cut -d= -f2- |  tr -d ' ')
#				echo "Credits in log $CREDITTOTAL"
#				echo "Total credits are $CREDITSTOTAL on person and $BALANCECREDITS in bank"
#				echo "Credits to be deposited $2 "
				if [ "$CREDITSTOTAL" -ge "$2" ]
				then
#					echo "enough money detected"
					NEWBALANCE=$(( $2 + $BALANCECREDITS ))
					NEWCREDITS=$(( $CREDITSTOTAL - $2 ))
#					echo "new bank balance is $NEWBALANCE"
					as_user "sed -i 's/CurrentCredits=$CREDITSTOTAL/CurrentCredits=$NEWCREDITS/g' $PLAYERFILE/$1"
					as_user "sed -i 's/CreditsInBank=$BALANCECREDITS/CreditsInBank=$NEWBALANCE/g' $PLAYERFILE/$1"
					#					as_user "sed -i '4s/.*/CreditsInBank=$NEWBALANCE/g' $PLAYERFILE/$1"
					as_user "screen -p 0 -S $SCREENID -X stuff $'/give_credits $1 -$2\n'"
					as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALATIC BANK You successfully deposited $2 credits\n'"
					as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALATIC BANK Your balance is now $NEWBALANCE\n'"
					as_user "echo '$1 deposited $2' >> $BANKLOG"
				else
					as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALATIC BANK Insufficient money\n'"
#					echo "not enough money"
				fi
			else
#				echo "Time difference to great, playerfile not updated recently"
				as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Connecting to GALACTICE BANK servers failed\n'"
			fi
		fi
	fi	
}

function COMMAND_WITHDRAW(){ 
#Takes money out of your server account and gives it to your player
#USAGE: !WITHDRAW <Amount>
#	echo "Withdraw command"
	if [ "$#" -ne "2" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !WITHDRAW <Amount>\n'"
	else

		if ! test "$2" -gt 0 2> /dev/null
		then
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALACTIC BANK - You must put in a positive number\n'"
		else
#			echo "Withdraw $2"
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALACTIC BANK - Connecting to servers\n'"
			BALANCECREDITS=$(grep CreditsInBank $PLAYERFILE/$1 | cut -d= -f2 | tr -d ' ')
#			echo "bank balance is $BALANCECREDITS"
			if [ "$2" -le "$BALANCECREDITS" ]
			then
				NEWBALANCE=$(( $BALANCECREDITS - $2 ))
#				echo "new balance for bank account is $NEWBALANCE"
				as_user "screen -p 0 -S $SCREENID -X stuff $'/give_credits $1 $2\n'"
				as_user "sed -i 's/CreditsInBank=$BALANCECREDITS/CreditsInBank=$NEWBALANCE/g' $PLAYERFILE/$1"
				as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALATIC BANK You successfully withdrawn $2 credits\n'"
				as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALATIC BANK Your balance is $NEWBALANCE credits\n'"
				as_user "echo '$1 witdrew $2' >> $BANKLOG"
			else
				as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALACTIC BANK - You have insufficient funds\n'"
			fi
		fi
	fi
}
function COMMAND_TRANSFER(){ 
#Sends money from your bank account to another players account
#USAGE: !TRANSFER <Player> <Amount>
	if [ "$#" -ne "3" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !TRANSFER <Player> <Amount>\n'"
	else
#	echo "Transfer $1 a total of $3 credits"
		if ! test "$3" -gt 0 2> /dev/null
		then
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALACTIC BANK - You must put in a positive number\n'"
		else 
			if [ -e $PLAYERFILE/$2 ] >/dev/null 
			then
				as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALACTIC BANK - Connecting to servers\n'"
				BALANCECREDITS=$(grep CreditsInBank $PLAYERFILE/$1 | cut -d= -f2 | tr -d ' ')
#				echo "Player transferring has $BALANCECREDITS in account"
				if [ "$3" -lt "$BALANCECREDITS" ]
				then
					TRANSFERBALANCE=$(grep CreditsInBank $PLAYERFILE/$2 | cut -d= -f2 | tr -d ' ')
#					echo "Player receiving has $TRANSFERBALANCE in his account"
					NEWBALANCETO=$(( $3 + $TRANSFERBALANCE ))
					NEWBALANCEFROM=$(( $BALANCECREDITS - $3 ))
#					echo "Changing $1 account to $NEWBALANCEFROM and $2 account to $NEWBALANCETO"
					as_user "sed -i 's/CreditsInBank=$BALANCECREDITS/CreditsInBank=$NEWBALANCEFROM/g' $PLAYERFILE/$1"
					as_user "sed -i 's/CreditsInBank=$TRANSFERBALANCE/CreditsInBank=$NEWBALANCETO/g' $PLAYERFILE/$2"
					as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALATIC BANK - You sent $3 credits to $2\n'"
					as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALATIC BANK - Your balance is now $NEWBALANCEFROM\n'"
					as_user "echo '$1 transferred to $2 in the amount of $3' >> $BANKLOG"
				else
					as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALACTIC BANK - Not enough credits\n'"
				fi
			else 
				as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALACTIC BANK - No account found\n'"
			fi
		fi
	fi
}
function COMMAND_BALANCE(){
#Tells the player how much money is stored in their server account
#USAGE: !BALANCE
	if [ "$#" -ne "1" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !BALANCE\n'"
	else
		BALANCECREDITS=$(grep CreditsInBank $PLAYERFILE/$1 | cut -d= -f2 | tr -d ' ')
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALACTIC BANK - You have $BALANCECREDITS credits\n'"
	fi
}
function COMMAND_FDEPOSIT(){
#Allows you to deposit credits into a shared faction bank account
#USAGE: !FDEPOSIT <Amount>
	if [ "$#" -ne "2" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !FACTIONDEPOSIT <Amount>\n'"
	else
		if [ "$2" -gt 0 ] 2>/dev/null
		then
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Connecting to GALACTICE BANK servers\n'"
			log_playerinfo $1
			FACTION=$(grep "PlayerFaction=" $PLAYERFILE/$1 | cut -d= -f2)
			if [ ! $FACTION = "None" ]
			then
				create_factionfile $FACTION
				CURRENTTIME=$(date +%s)
#				echo "Current time $CURRENTTIME"
				OLDTIME=$(grep PlayerLastUpdate $PLAYERFILE/$1 | cut -d= -f2- |  tr -d ' ')
#				echo "Old time from playerfile $OLDTIME"
				ADJUSTEDTIME=$(( $CURRENTTIME - 10 ))
#				echo "Adjusted time to remove 10 seconds $ADJUSTEDTIME"
				if [ "$OLDTIME" -ge "$ADJUSTEDTIME" ]
				then
					BALANCECREDITS=$(grep CreditsInBank $FACTIONFILE/$FACTION | cut -d= -f2- |  tr -d ' ')
#					echo $BALANCECREDITS
					CREDITSTOTAL=$(grep CurrentCredits $PLAYERFILE/$1 | cut -d= -f2- |  tr -d ' ')  
#					echo "Credits in log $CREDITTOTAL"
#					echo "Total credits are $CREDITSTOTAL on person and $BALANCECREDITS in bank"
#					echo "Credits to be deposited $2 "
					if [ "$CREDITSTOTAL" -ge "$2" ]
					then 
#						echo "enough money detected"
						NEWBALANCE=$(( $2 + $BALANCECREDITS ))
						NEWCREDITS=$(( $CREDITSTOTAL - $2 ))
#						echo "new bank balance is $NEWBALANCE"
						as_user "sed -i 's/CurrentCredits=.*/CurrentCredits=$NEWCREDITS/g' $PLAYERFILE/$1"
						as_user "sed -i 's/CreditsInBank=.*/CreditsInBank=$NEWBALANCE/g' $FACTIONFILE/$FACTION"
#						as_user "sed -i '4s/.*/CreditsInBank=$NEWBALANCE/g' $PLAYERFILE/$1"
						as_user "screen -p 0 -S $SCREENID -X stuff $'/give_credits $1 -$2\n'"
						as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALATIC BANK You successfully deposited $2 credits\n'"
						as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALATIC BANK Your factions balance is now $NEWBALANCE\n'"
						as_user "echo '$1 deposited $2 into $FACTION bank account' >> $BANKLOG"
					else
						as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALATIC BANK Insufficient money\n'"
#						echo "not enough money"
					fi
				else
#					echo "Time difference to great, playerfile not updated recently"
					as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Connecting to GALACTICE BANK servers failed\n'"
				fi
			else
				as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALACTICE BANK - You are not in a faction\n'"
			fi
		else
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Please enter a positive whole number\n'"
		fi
	fi
}
function COMMAND_FWITHDRAW(){
#Allows you to withdraw from a shared faction account
#USAGE: !FWITHDRAW <Amount>
	if [ "$#" -ne "2" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !FACTIONWITHDRAW <Amount>\n'"
	else
		if [ "$2" -gt 0 ] 2>/dev/null
		then
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALACTICE BANK - Connecting to servers\n'"
			log_playerinfo $1
			FACTION=$(grep "PlayerFaction=" $PLAYERFILE/$1 | cut -d= -f2)
			if [ ! $FACTION = "None" ]
			then
				create_factionfile $FACTION
				BALANCECREDITS=$(grep CreditsInBank $FACTIONFILE/$FACTION | cut -d= -f2 | tr -d ' ')
#				echo "bank balance is $BALANCECREDITS"
				if [ "$2" -le "$BALANCECREDITS" ]
				then
					NEWBALANCE=$(( $BALANCECREDITS - $2 ))
#					echo "new balance for bank account is $NEWBALANCE"
					as_user "screen -p 0 -S $SCREENID -X stuff $'/give_credits $1 $2\n'"
					as_user "sed -i 's/CreditsInBank=$BALANCECREDITS/CreditsInBank=$NEWBALANCE/g' $FACTIONFILE/$FACTION"
					as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALATIC BANK You successfully withdrawn $2 credits\n'"
					as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALATIC BANK The factions balance is $NEWBALANCE credits\n'"
					as_user "echo '$1 witdrew $2 from $FACTION' >> $BANKLOG"
				else
					as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALACTIC BANK - Your faction has insufficent funds\n'"
				fi
			else
				as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALACTIC BANK - You are not in a faction\n'"
			fi
		else
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Please enter positive whole numbers only.\n'"
		fi
	fi

}
function COMMAND_FBALANCE(){
#Allows you to see how many credits are in a shared faction account
#USAGE: !FBALANCE
	if [ "$#" -ne "1" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !BALANCE\n'"
	else
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALACTIC BANK - Connecting to servers\n'"
		log_playerinfo $1
		FACTION=$(grep "PlayerFaction" $PLAYERFILE/$1 | cut -d= -f2)
		if [ ! $FACTION = "None" ]
		then
			BALANCECREDITS=$(grep CreditsInBank $FACTIONFILE/$FACTION | cut -d= -f2 | tr -d ' ')
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALACTIC BANK - Your faction has $BALANCECREDITS credits\n'"
		else
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 GALACTIC BANK - You are not in a faction\n'"
		fi
	fi
}
function COMMAND_VOTEEXCHANGE(){
#Converts the specified number of voting points into credits at the rate of 1,000,000 credits per vote
#USAGE: !VOTEEXCHANGE <Amount>
	if [ "$#" -ne "2" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !VOTEEXCHANGE <Amount>\n'"
	else
		if [ $2 -gt 0 ] 2>/dev/null
		then
			BALANCECREDITS=$(grep CreditsInBank $PLAYERFILE/$1 | cut -d= -f2 | tr -d ' ')
			VOTEBALANCE=$(grep "VotingPoints=" $PLAYERFILE/$1 | cut -d= -f2)
			if [ $VOTEBALANCE -ge $2 ]
			then
				NEWVOTE=$(($VOTEBALANCE - $2))
				NEWCREDITS=$(($BALANCECREDITS + $CREDITSPERVOTE * $2))
				as_user "sed -i 's/CreditsInBank=.*/CreditsInBank=$NEWCREDITS/g' $PLAYERFILE/$1"
				as_user "sed -i 's/VotingPoints=.*/VotingPoints=$NEWVOTE/g' $PLAYERFILE/$1"
				as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 You traded in $2 voting points for $(($BALANCECREDITS + $CREDITSPERVOTE * $2)) credits. The credits have been sent to your bank account.\n'"
			else
				as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 You dont have enough voting points to do that! You only have $VOTEBALANCE voting points\n'"
			fi
		else
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid amount entered. Please only use positive whole numbers.\n'"
		fi
	fi
}

#Rank Commands
function COMMAND_RANKME(){
#Tells you what your rank is and what commands are available to you
#USAGE: !RANKME
	if [ "$#" -ne "1" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !RANKME\n'"
	else
		USERRANK=$(grep Rank "$PLAYERFILE/$PLAYERCHATID" | awk -F "=" '{print $2}')
		USERCOMMANDS=$(grep $USERRANK $RANKCOMMANDS | cut -d" " -f2-)
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Commands available are $USERCOMMANDS\n'"
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 $1 rank is $USERRANK\n'"
	fi
}
function COMMAND_RANKLIST(){
#Lists all the available ranks
#USAGE: !RANKLIST
	if [ "$#" -ne "1" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !RANKLIST\n'"
	else
	    LISTRANKS=( $(cut -d " " -f 1 $RANKCOMMANDS) )
		CHATLIST=${LISTRANKS[@]}	
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 The Ranks are: $CHATLIST \n'"
	fi
}
function COMMAND_RANKSET(){
#Sets the rank of the player
#USAGE: !RANKSET <Player> <Rank>
	if [ "$#" -ne "3" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !RANKSET <Name> <Rank>\n'"
	else
		if grep -q $3 $RANKCOMMANDS
		then
			if [ -e $PLAYERFILE/$2 ]
			then
				as_user "sed -i 's/Rank=.*/Rank=$3/' $PLAYERFILE/$2"
				as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 $2 is now the rank $3\n'"
			else
				as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Playerfile for $2 does not exist\n'"
			fi
		else
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 That rank does not exist\n'"
		fi
	fi
}
function COMMAND_RANKUSER(){
#Finds out the rank of the given player
#USAGE: !RANKUSER <Player>
	if [ "$#" -ne "2" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !RANKUSER <Name>\n'"
	else
		if [ -e $PLAYERFILE/$2 ]
		then
			RANKUSERSTING=$(grep Rank "$PLAYERFILE/$PLAYERCHATID" | awk -F "=" '{print $2}')
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 $RANKUSERSTING\n'"
		else
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 $2 has no current Rank or does not exist\n'"
		fi
	fi
}
function COMMAND_RANKCOMMAND(){
#Lists all commands available to you
#USAGE: !RANKCOMMAND
	if [ "$#" -ne "1" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !RANKCOMMAND\n'"
	else		
		RANKUCOMMAND=$(grep $PLAYERRANK $RANKCOMMANDS | cut -d" " -f2-)
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Commands are $RANKUCOMMAND\n'"
	fi
}

#Functional Commands

function COMMAND_VOTEBALANCE(){ 
#Tells you how many voting points you have saved up
#USAGE: !VOTEBALANCE
	as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 You have $(grep "VotingPoints=" $PLAYERFILE/$1 | cut -d= -f2 | tr -d " " ) votes to spend!\n'"
}

#Utility Commands
function COMMAND_HELP(){ 
#Provides help on any and all functions available to the player
#USAGE: !HELP <Command (optional)>
	if [ "$#" -gt "2" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !HELP <Command (Optional)>\n'"
	else		
		PLAYERRANK[$1]=$(grep "Rank=" $PLAYERFILE/$1 | cut -d= -f2)
		ALLOWEDCOMMANDS[$1]=$(grep $PLAYERRANK $RANKCOMMANDS)
		HELPCOMMAND=$(echo $2 | tr [a-z] [A-Z])
		if [ "$#" -eq "1" ]
		then
			if [[ "${ALLOWEDCOMMANDS[$1]}" =~ "-ALL-" ]]
			then
				OLD_IFS=$IFS
				IFS=$'\n'
				for LINE in $(tac $DAEMONPATH)
				do
					if [[ $LINE =~ "function COMMAND_" ]] && [[ ! $LINE =~ "#" ]] && [[ ! $LINE =~ "\$" ]]
					then
						as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 $(echo $LINE | cut -d"_" -f2 | cut -d"(" -f1) \n'"
					fi
				done
				as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Type !HELP <Command> to get more info about that command!\n'"
				IFS=$OLD_IFS
			else
				as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 $(echo ${ALLOWEDCOMMANDS[$1]} | cut -d" " -f2-)\n'"
				as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 All available commands are:\n'"
			fi
		else
			function_exists "COMMAND_$HELPCOMMAND"
			if [[ "$FUNCTIONEXISTS" == "0" ]]
			then
				if [[ "${ALLOWEDCOMMANDS[$1]}" =~ "$HELPCOMMAND" ]] || [[ "${ALLOWEDCOMMANDS[$1]}" =~ "-ALL-" ]]
				then
					OLDIFS=$IFS
					IFS=$'\n'
					HELPTEXT=( $(grep -A3 "function COMMAND_$HELPCOMMAND()" $DAEMONPATH) )
					as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 $(echo ${HELPTEXT[2]} | cut -d\# -f2)\n'"
					as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 $(echo ${HELPTEXT[1]} | cut -d\# -f2)\n'"
					IFS=$OLDIFS
				else
					as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 You dont have permission to use $2\n'"
				fi
			else
				as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 That command doesnt exist.\n'"
			fi
		fi
	fi
}
function COMMAND_CORE(){
#Provides you with a ship core. Only usable once every 10 minutes
#USAGE: !CORE
	if [ "$#" -ne "1" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !CORE\n'"
	else	
		OLDPLAYERLASTCORE=$(grep PlayerLastCore $PLAYERFILE/$1 | cut -d= -f2- | tr -d ' ')
		CURRENTTIME=$(date +%s)
		ADJUSTEDTIME=$(( $CURRENTTIME - 600 ))
		if [ "$ADJUSTEDTIME" -gt "$OLDPLAYERLASTCORE" ]
		then
			as_user "screen -p 0 -S $SCREENID -X stuff $'/giveid $1 1 1\n'"
			as_user "sed -i 's/PlayerLastCore=$OLDPLAYERLASTCORE/PlayerLastCore=$CURRENTTIME/g' $PLAYERFILE/$1"
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 You have received one core. There is a 10 minute cooldown before you can use it again\n'"
		else
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Please allow Core command to cooldown. $((600-($(date +%s)-$(grep "PlayerLastCore=" $PLAYERFILE/$1 | cut -d= -f2)))) seconds left\n'"
		fi
	fi
}

function COMMAND_PING(){
#With this command, you can check if the server is responsive
#USAGE: !PING
	as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 !PONG\n'"
}

function COMMAND_LOAD(){
#A little info command to see how much of the system ressources are gathered from the starmade server process
#USAGE: !LOAD
	STAR_RAWLOAD_CPU=$(ps aux | grep java | grep StarMade.jar | grep $PORT | grep -v "rlwrap\|sh" | awk '{print $3}')
	CPU_CORES=$(grep processor /proc/cpuinfo | wc -l)
	STAR_LOAD_CPU=$(($STAR_RAWLOAD_CPU/$CPU_CORES))
	STAR_LOAD_MEM=$(ps aux | grep java | grep StarMade.jar | grep $PORT | grep -v "rlwrap\|sh" | awk '{print $4}')
	as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 CPU: $STAR_LOAD_CPU% MEM: $STAR_LOAD_MEM%.\n'"
	as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Server load is currently:\n'"
}

#Vanilla Admin Commands

function COMMAND_LOADSHIP(){
#Spawns in the specified ship from the catalogue to the specified coords
#USAGE: !LOADSHIP <Blueprint Name> <Entity Name> <X> <Y> <Z>
	if [ "$#" -ne "6" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !LOADSHIP <Blueprint Name> <Entity Name> <X> <Y> <Z>\n'"
	else
		as_user "screen -p 0 -S $SCREENID -X stuff $'/spawn_entity $2 $3 $4 $5 $6 0 false\n'"
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 The blueprint $2 has been spawned in sector $4,$5,$6 and is called $3\n'"
	fi
}
function COMMAND_GIVEMETA(){ 
#Gives you, or another player the specified meta item
#USAGE: !GIVEMETA <Player (optional)> <METAUTEN>
	if [ "$#" -ne "2" ] && [ "$#" -ne "3" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !GIVE <Playername (optional)> <Metaitem>\n'"
	else
		if [ "$#" -eq "2" ] 2>/dev/null
		then
			as_user "screen -p 0 -S $SCREENID -X stuff $'/give_metaitem $1 $2\n'"
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 You received $2\n'"
		else
			as_user "screen -p 0 -S $SCREENID -X stuff $'/give_metaitem $2 $3\n'"
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 $2 received $3\n'"
		fi
	fi
}
function COMMAND_CLEAR(){
#Removes all items from your inventory
#USAGE: !CLEAR
	if [ "$#" -ne "1" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !CLEAR\n'"
	else	
		as_user "screen -p 0 -S $SCREENID -X stuff $'/give_all_items $1 -99999\n'"
as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Your inventory has been cleaned\n'"		
	fi
}
function COMMAND_SPAWNSTOP(){
#Prevents enemies from attacking you while insider the specified sector
#USAGE: !SPAWNSTOP <X> <Y> <Z>
	if [ "$#" -ne "4" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !SPAWNSTOP <X> <Y> <Z>\n'"
	else		
		as_user "screen -p 0 -S $SCREENID -X stuff $'/sector_chmod $2 $3 $4 + peace\n'"
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Sector $2,$3,$4 is no longer hostile\n'"
	fi
}
function COMMAND_SPAWNSTART(){
#Allows enemies to start attacking you inside the specified sector
#USAGE: !SPAWNSTART <X> <Y> <Z>
	if [ "$#" -ne "4" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !SPAWNSTART <X> <Y> <Z>\n'"
	else		
		as_user "screen -p 0 -S $SCREENID -X stuff $'/sector_chmod $2 $3 $4 - peace\n'"
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Sector $2,$3,$4 is hostile again\n'"
	fi
}

#Debug Commands
function COMMAND_MYDETAILS(){
#Tells you all details that are saved inside your personal player file
#USAGE: !MYDETAILS
	if [ "$#" -ne "1" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !MYDETAILS\n'"
	else
		for ENTRY in $(tac $PLAYERFILE/$1)
		do
			as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 $ENTRY\n'"
		done		
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 All details inside your playerfile:\n'"
	fi
}
function COMMAND_THREADDUMP(){
#A debug tool that outputs what the server is doing to a file
#USAGE: !THREADDUMP
	if [ "$#" -ne "2" ]
	then
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 Invalid parameters. Please use !THREADDUMP\n'"
	else
		PID=$(ps aux | grep -v grep | grep $SERVICE | grep -v tee | grep port:$PORT | awk '{print $2}') 
		as_user "jstack $PID >> $STARTERPATH/logs/threaddump$(date +%H%M%S.%N).log"
		as_user "screen -p 0 -S $SCREENID -X stuff $'/pm $1 The current java process has been exported to logs/threaddump$(date +%H%M%S.%N).log\n'"
	fi
}

#------------------------------| EOF chatcommands.sh |-----------------------------------------
