#!/usr/bin/env bash

convertsecs() {
    ((h=${1}/3600))
    ((m=(${1}%3600)/60))
    ((s=${1}%60))
    printf "%02d:%02d:%02d\n" $h $m $s
}

start_monitor=`date +%s`

if [ $# -eq 1 ]; then
    name=$1   
    duration=10                        
    display_gfx=0

elif [ $# -eq 2 ]; then                                                                
    name=$1
    duration=$2
    display_gfx=0

elif [ $# -eq 3 ]; then                                                                
    name=$1
    duration=$2
    display_gfx=$3

else 
    echo "Warning: No parameters provided to identify job in SLURM queue."
    name=$( whoami | cut -c1-8 )
    echo "Trying by username $name"    
    duration=60                                                                                                                                            
fi                                                                                                                                                     
                                                                                                                                                            
# jq=$( squeue -o "%.35j %.7i %.8u %.2t %.10M %.6D %R " | awk -F_ 'NR > 1 {printf"%s\n", $1}' | awk 'NR==1{ print $1}' )

echo
echo "Waiting for SLURM jobs to finish. This may take a while, take a break."

if [ $display_gfx -eq 1 ]; then
    case "$(( ( RANDOM % 4 )  + 1 ))" in
	"1")
	    echo
	    echo
	    echo "   //\\"
	    echo "   V  \\"
	    echo "    \\  \\_"
	    echo "     \\,'.\`-."
	    echo "      |\\ \\\`. \`. "
	    echo "      ( \  \`. \`-.                        _,.-:\\"
	    echo "       \ \   \`.  \`-._             __..--' ,-';/"
	    echo "        \\ \`.   \`-.   \`-..___..---'   _.--' ,'/"
	    echo "         \`. \`.    \`-._        __..--'    ,' /"
	    echo "           \`. \`-_     \`\`--..''       _.-' ,'"
	    echo "             \`-_ \`-.___        __,--'   ,'"
	    echo "                \`-.__  \`----\"\"\"    __.-'"
	    echo "                     \`--..____..--'"
	    echo
	    ;;
	"2")
	    echo
	    echo
	    echo "                        //"
	    echo "                       //"
	    echo "                      //"
	    echo "                     //"
	    echo "              _______||"
	    echo "         ,-'''       ||\`-."
	    echo "        (            ||   )"
	    echo "        |\`-..._______,..-'|"
	    echo "        |            ||   |"
	    echo "        |     _______||   |"
	    echo "        |,-'''_ _  ~ ||\`-.|"
	    echo "        |  ~ / \`-.\ ,-\' ~|"
	    echo "        |\`-...___/___,..-'|"
	    echo "        |    \`-./-'_ \/_| |"
	    echo "        | -'  ~~     || -.|"
	    echo "        (   ~      ~   ~~ )"
	    echo "         \`-..._______,..-'"
	    echo
	    ;;

	"3")
	    echo
	    echo
	    echo 
	    echo "      ___  ___  ___  ___  ___.---------------."
	    echo "    .'\__\'\__\'\__\'\__\'\__,\`   .  ____ ___ \ "
	    echo "    |\/ __\/ __\/ __\/ __\/ _:\   |\`.  \  \___ \ "
	    echo "     \\\\'\__\'\__\'\__\'\__\'\_\`.__|\"\"\`. \  \___ \ "
	    echo "      \\\\/ __\/ __\/ __\/ __\/ _:                 \ "
	    echo "       \\\\'\__\'\__\'\__\ \__\'\_;-----------------\`"
	    echo "        \\\\/   \/   \/   \/   \/ :                 |"
	    echo "         \|______________________;________________| "
	    echo 
	    ;;
	"4")
	    echo
	    echo 
	    echo "                        ("
	    echo "                          )     ( "
	    echo "                   ___...(-------)-....___ "
	    echo "               .-\"\"       )    (          \"\"-. "
	    echo "         .-'``'|-._             )         _.-| "
	    echo "        /  .--.|   \`\"\"---...........---\"\"\`   | "
	    echo "       /  /    |                             | "
	    echo "       |  |    |                             | "
	    echo "        \  \   |                             | "
	    echo "         \`\ \`\ |                             | "
	    echo "           \`\ \`|                             | "
	    echo "           _/ /\\                             / "
	    echo "          (__/  \\                           / "
	    echo "       _..---\"\"\` \\                         /\`\"\"---.._ "
	    echo "    .-'           \\                       /          '-. "
	    echo "   :               \`-.__             __.-'              : "
	    echo "   :                  ) \"\"---...---\"\" (                 : "
	    echo "    '._               \`\"--...___...--\"\`              _.' "
	    echo "      \\\"\"--..__                              __..--\"\"/ "
	    echo "       '._     \"\"\"----.....______.....----\"\"\"     _.' "
	    echo "          \`\"\"--..,,_____            _____,,..--\"\"\` "
	    echo "                        \`\"\"\"----\"\"\"\` "
	    echo 
	    ;;
    esac
fi

while true; do
    nq=$( squeue -o "%.35j %.7i %.8u %.2t %.10M %.6D %R " | grep $name | wc -l )
    npr=$( squeue -o "%.35j %.7i %.8u %.2t %.10M %.6D %R " | grep $name | awk 'NR==1{print $1}' )

    if [ $nq -eq 0 ]; then
	echo
	echo "SLURM jobs finished. Continuing with next processing step."
	echo
	break
    else
	#squeue_status=$(squeue -n $name)
	#echo $squeue_status
	#echo

	time_now=`date +%s`
	runtime_seconds=$((time_now-start_monitor))	
	runtime_formated=$(convertsecs $runtime_seconds)
	echo "Running for $runtime_formated and still $nq jobs left in the queue."

	
	# squeue -o "%.20j %.7i %.8u %.2t %.10M %.6D %R "

	sleep ${duration}s

	#nlines=$( echo $squeue_status | wc -l) #Calculate number of lines for the output previously printed
	#for (( i=0; i <= $(($LINES)); i++ ));do #For each line printed as a result of "timedatectl"
	tput cuu1 #Move cursor up by one line
	tput el #Clear the line
	#done
    fi
done
