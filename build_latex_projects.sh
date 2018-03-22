#!/bin/bash

# @Author: StarryTony
# @Date:   2018-03-20 23:21:13
# @Last Modified by:   StarryTony
# @Last Modified time: 2018-03-20 23:46:35
# @Description: This lightweight script helps to build complicated latex projects.

#   -------------------------------
#   App functions
#   -------------------------------

default(){
	echoFuncSeperator "default"

    count=0
    for index in "${defaultConfigList[@]}"; do
        KEY="${index%%::*}"
        FUN="${index#*::}"
        FUN="${FUN%::*}"
        FUN="${FUN//[[:space:]]/}"
        DES="${index##*::}"

        if [[ "${FUN}" != "" ]]; then
            item="${KEY}=${FUN}"
            eval ${item}
        fi

        count=$((${count}+1))
    done 

    show_debug_msg "${ICON_ACCEPT} : Default Configuration Loaded." ${ACCEPT_LEVEL}
}

read_profile(){
	echoFuncSeperator "read_profile"

	# read from profile
	while read line; do
		eval "$line"
	done < "${profile_path}"

	show_debug_msg "${ICON_ACCEPT} : System Configuration Loaded." ${ACCEPT_LEVEL}
}

read_project_specified_config(){
	echoFuncSeperator "read_project_specified_config"

	# read from profile
	while read line; do
		eval "$line"
	done < "${project_specified_config}"

	show_debug_msg "${ICON_ACCEPT} : Project specified configuration Loaded." ${ACCEPT_LEVEL}
}

update_project_specified_config(){
	echoFuncSeperator "update_project_specified_config"

    if [[ ! -d "${project_path}" ]]; then
    	show_debug_msg "${ICON_ERR} : the project ${err_msg_color}${project_path}${NC} is not found." ${ERR_LEVEL}
    	return ${ERR_CODE}
    fi

    # if profile folder not exist, create it
    if [[ "${project_path}" != "" ]] && [[ ! -d "${project_specified_conf_folder}" ]]; then
        mkdir "${project_specified_conf_folder}"
    fi

    count=0
    for index in "${ProjectSpecifiedConfigList[@]}"; do
        KEY="${index%%::*}"

        if [[ ${count} == 0 ]]; then
            item="echo "${KEY}=\\\"\${${KEY}}\\\"" > "\"${project_specified_config}\"""
        else
            item="echo "${KEY}=\\\"\${${KEY}}\\\"" >> "\"${project_specified_config}\"""
        fi

        eval ${item}
        count=$((${count}+1))
    done 

    show_debug_msg "${ICON_ACCEPT} : Project specified configuration updated." ${ACCEPT_LEVEL}
}

load_project(){
	echoFuncSeperator "load_project"

    if [ -f "${profile_path}" ]
    then
        read_profile      
    else    
        default
    fi
    
    # if profile folder not exist, create it
    if [ ! -d "${profile_folder}" ]
    then
        mkdir "${profile_folder}"
    fi

    if [[ ! -d "${project_path}" ]]; then
    	show_debug_msg "${ICON_ERR} : the project ${err_msg_color}${project_path}${NC} is not found." ${ERR_LEVEL}
    	return ${ERR_CODE}
    else
	 	cd "${project_path}"

		# set folders (const)
		if [[ "${project_path}" != "" ]]; then
			project_specified_conf_folder=${project_path}"/project_specified_config"
			project_specified_config=${project_specified_conf_folder}"/project_specified.config"

			backup_folder=${project_specified_conf_folder}"/backup"
		fi

		# override with project specified configuration
	    if [ -f "${project_specified_config}" ]
	    then
	        read_project_specified_config   
	    else
	    	echo -e "${ICON_WARN} No project specified configuration found."   
	    fi

	    # auto find the most recent version number
	    autoFindVersionNum tmp_tex_version_count
    	if [[ "${tex_version_count}" == "" ]] || [[ $((${tex_version_count})) -lt $((${tmp_tex_version_count})) ]]; then
			tex_version_count=${tmp_tex_version_count}
		fi

		updateConfig

		show_debug_msg "${ICON_ACCEPT} : Project loaded." ${ACCEPT_LEVEL}	
    fi
}

autoFindVersionNum(){
   # list all backups
	lb_except_list=(
		"${project_specified_conf_folder##*/}"
		)

	lb_str="find \"${backup_folder}\" -type d -depth 1"
	count=0
    for index in "${lb_except_list[@]}"; do
        KEY="${index%%::*}"

        lb_str=${lb_str}" -not -iname \"${KEY}\""

        count=$((${count}+1))
    done  
    lb_str=${lb_str}" -print0 | xargs -0 stat -f '%Sm %N,' | sort"
	local bak_list=`eval "${lb_str}"`

	# sort list
	IFS=$',' 
	bak_list=($(sort <<<"${bak_list[*]}"))
	unset IFS

    # find mostly recent diff version (the last one)
    candidate_diff=""
    for index in "${!bak_list[@]}"; do
        KEY="${bak_list[index]//*[[:space:]]\///}"
        KEY_time=`date -r "${KEY}" '+%Y-%m-%d %H:%M:%S'`
        KEY_timestamp=`date -r "${KEY}" '+%s'`

        KEY=${KEY##*\/}
		
        item_str=""
        if [[ ${index} == 0 ]]; then
        	item_str="Available history versions: "
        else
        	item_str="                            "
        fi

        item_str=${item_str}"[${KEY##*_}] ${profile_color}${KEY}${NC} " 
		item_str=${item_str}"${highlight_time}${KEY_time}${NC}"

		candidate_diff=${KEY##*_} 

		show_debug_msg "${item_str}" ${NORMAL_LEVEL}
    done  
  
    echo -e "Recent changed version: ${profile_color}${candidate_diff}${NC}"

	eval "$1=\"${candidate_diff}\""
}

tryAutoFindMainTex(){
	echoFuncSeperator "tryAutoFindMainTex"

	if [[ "${project_path}" != "" ]]; then
		cd "${project_path}"

		# try auto-find project name (name of .tex))
		temp_name=$(find . -type f -maxdepth 1 -iname "*.tex")

		OLD_IFS="$IFS" # OLD_IFS用于备份默认的分隔符，使用完后将之恢复默认
		IFS=$'\n'  # A list of characters that separate fields; used when the shell splits words as part of expansion.
		arr=($temp_name) 

		temp_project_name=""
		# loop in case of not only one tex file
		count=0
		arrayTex=()
		for item in ${arr[@]}
		do
			item=${item#./}
			item=${item%.tex}	

			arrayTex+=("${count}::${item}")
			echo -e "[${count}] ${profile_color}${item}${NC}"

			if [[ item != "" ]] && [[ item != "Chapter" ]] ; then
				temp_project_name="$item"
			fi
			count=$((${count}+1))
		done
		IFS="$OLD_IFS" 
		# unset IFS # 或者使用unset恢复默认值
		
		# re-choose the main .tex file manually if there are more than 1 .tex files
		if [[ ${count} > 1 ]]; then
			echo "There are ${count} .tex files, please specify the main .tex file (you can use index number or the .tex file name, the first .tex file will be chosen if nothing input):"
			read temp_project_name

			if [[ "${temp_project_name}" == "" ]]; then
				temp_project_name=0
			fi

			echo "-------------------"
			for index in "${arrayTex[@]}"; do
				KEY="${index%%::*}"
				VALUE="${index##*::}"
				# echo "[${KEY}] ${VALUE}"

				if [[ "${temp_project_name}" =~ ^[0-9]+$ ]] && [[ "${temp_project_name}" == "${KEY}" ]]; then
					temp_project_name="${VALUE}"
				fi
			done
		fi

		isTexExist=false
		if [[ temp_project_name != "" ]] ; then
			# check if the specified .tex file exists
			for index in "${arrayTex[@]}"; do
				KEY="${index%%::*}"
				VALUE="${index##*::}"

				if [[ "${temp_project_name}" == "${VALUE}" ]]; then
					project_name="$temp_project_name"
					isTexExist=true

					show_debug_msg "${ICON_ACCEPT} : New main tex ${profile_color}${project_name}.tex${NC} has been chosen." ${ACCEPT_LEVEL}
				fi
			done	

			if [[ ${isTexExist} == false ]]; then
				show_debug_msg "${ICON_ERR} : the ${err_msg_color}${temp_project_name}.tex${NC} file does not exist." ${ERR_LEVEL}
				# tryAutoFindMainTex
				return ${ERR_CODE}
			fi		
		else
			tryAutoFindMainTex	
		fi

		# write new configuration to profile file
		updateConfig
		show_debug_msg "${ICON_ACCEPT} : New main tex ${profile_color}${project_name}.tex${NC} has been loaded." ${ACCEPT_LEVEL}
	else
		show_debug_msg "${ICON_ERR} : the project_path \"${profile_color}${profile_path}${NC}\" is invalid." ${ERR_LEVEL}
	fi

	
}

updateConfig(){
	echoFuncSeperator "updateConfig"

    count=0
    for index in "${defaultConfigList[@]}"; do
        KEY="${index%%::*}"

        if [[ ${count} == 0 ]]; then
            item="echo "${KEY}=\\\"\${${KEY}}\\\"" > "\"${profile_path}\"""
        else
            item="echo "${KEY}=\\\"\${${KEY}}\\\"" >> "\"${profile_path}\"""
        fi

        eval ${item}
        count=$((${count}+1))
    done 

    update_project_specified_config

    show_debug_msg "${ICON_ACCEPT} : System config updated." ${ACCEPT_LEVEL}
}

# $1 -> msg; $2 -> msg_debug_level
show_debug_msg(){
	if [[ "$2" =~ ^[0-9]+$ ]];then
		msg_debug_level=$(($2))
	else
		msg_debug_level=${DEBUG_LEVEL_MIN}
	fi
	
	if [[ ${DEBUG_LEVEL} -ge ${msg_debug_level} ]]; then
		now_time=`date '+%Y-%m-%d %H:%M:%S'`
		echo -e "${grey_time}${now_time}${NC} $1"
	fi

	# hasError? hasWarn?
	local msg_status=${1:0:4}
	msg_status=${msg_status//[[:space:]]/}

	case ${msg_status} in
		${ICON_ERR//[[:space:]]/})
			hasError=$((${hasError}+1))
			;;
		${ICON_WARN//[[:space:]]/})
			hasWarn=$((${hasWarn}+1))
			;;
		*)
			;;
	esac
}

updateRunHistory(){
    run_history=$1

    updateConfig
}

choose_project(){
	echoFuncSeperator "choose_project"

	prev_project_path=${project_path}
	echo "Please input the project path to compile:"
	read project_path

	if [[ "${project_path}" != "" ]]; then
		tryAutoFindMainTex

		show_debug_msg "${ICON_ACCEPT} : New project \"${profile_color}${project_path}${NC}\" has been choosen." ${ACCEPT_LEVEL}

		# load new project
		load_project
	else
		project_path=${prev_project_path}

		show_debug_msg "${ICON_WARN} : Nothing changed." ${WARN_LEVEL}
		return ${WARN_CODE}
	fi
}

clean_cache(){
	echoFuncSeperator "clean_cache"
	echo "Clean cache..."

	# clean dump files for recompile (bbl,aux,bib)	
	cache_list=(
		'*.bbl'
		'*.aux'
		'*.log'
		'*.blg'
		'*.toc'

		'*.bcf'
		'*.ilg'
		'*.lof'
		'*.lot'
		'*.nlo'
		'*.nls'
		'*.out'
		'*.run.xml'

		'*.idx'
		'*.ind'
		'*.acn'
		'*.acr'
		'*.alg'
		'*.glg'
		'*.glo'
		'*.gls'
		'*.ist'
		'*.fdb_latexmk'
		'*.fls'
		)

	count=0
    for index in "${cache_list[@]}"; do
        KEY="${index%%::*}"
        DES="${index##*::}"

        find "${project_path}" -type f -iname "${KEY}" -print0 | xargs -0 rm

        count=$((${count}+1))
    done  

	# only clean project.pdf
	# find "${project_path}" -type f -maxdepth 1 -iname "*.pdf" -print0 | xargs -0 rm
	# find "${project_path}" -type f -maxdepth 1 -iname "${project_name}.pdf" -print0 | xargs -0 rm
	
	show_debug_msg "${ICON_ACCEPT} : Clean cache... done." ${ACCEPT_LEVEL}
}

deep_clean_cache(){
	echoFuncSeperator "deep_clean_cache"
	echo "Deep clean cache..."

	# try to clean cache of biber for clean compilation
	rm -rf `biber --cache`

	# also remove output
	if [ -d "output" ]
	then
		rm -r "output"
	fi

	clean_cache

	show_debug_msg "${ICON_ACCEPT} : Deep clean cache... done" ${ACCEPT_LEVEL}
}

delete_all_backup(){
	if [ -d "${backup_folder}" ]
	then
	    echo -e "Delete all backups, ${menu_color}yes${NC} or ${menu_color}no${NC} (${menu_color}y${NC}/${menu_color}n${NC})?"
		read option
		echo ;	
		if [[ "${option}" == "y" ]] || [[ "${option}" == "yes" ]]; then
			rm -r "$backup_folder"
		else
			show_debug_msg "${ICON_WARN} : the operation has been cancelled." ${WARN_LEVEL}
			return ${WARN_CODE}
		fi
	fi
}

choose_pdf_compiler(){
	echoFuncSeperator "choose_pdf_compiler"
	echo -e "Current pdf Compiler: ${profile_color}${default_pdf_compiler}${NC}"

	pdf_compiler_list=(
		'pdflatex        ::A modification of TeX which allows it to output to PDF directly'
		'xelatex         ::Another modification of the underlying TeX engine, this time to support a wider range of characters beyond just plain English numbers and letters, and to include support for modern font formats'
		'lualatex        ::An attempt to extend the original TeX program with a more sensible programming language'
		'context         ::Provide an easy interface to advanced typography features'
		)

	count=0
    for index in "${pdf_compiler_list[@]}"; do
        KEY="${index%%::*}"
        DES="${index##*::}"

        echo -e "[${count}] ${menu_color}${KEY}${NC} -> ${DES}"
        count=$((${count}+1))
    done   

    echo -e "Please choose pdf compiler (you can use the index number or compiler name, default is \"pdflatex\" if nothing chosen): "
	read -n1 pdf_config
	echo ;	

	if [[ "${pdf_config}" =~ ^[0-9]+$ ]] && [[ $((${pdf_config})) -ge 0 ]] && [[ $((${pdf_config})) -le $((${count}-1)) ]]; then
		count=0
	    for index in "${pdf_compiler_list[@]}"; do
	        KEY="${index%%::*}"
	        KEY=${KEY//[[:space:]]/}
	        DES="${index##*::}"

	        if [[ "${pdf_config}" == "${count}" ]] || [[ "${pdf_config}" == "${KEY}" ]]; then
	        	default_pdf_compiler="${KEY}"
	        	echo -e "[${count}] ${menu_color}${KEY}${NC} has been chosen."
	        	return
	        fi

	        count=$((${count}+1))
	    done 
	elif [[ "${default_pdf_compiler}" != "" ]]; then
		default_pdf_compiler="pdflatex"
		echo -e "[0] ${menu_color}${default_pdf_compiler}${NC} has been chosen."
	else
		# do nothing
		echo -e "${ICON_WARN} Nothing changed."
		return ${WARN_CODE}
	fi
}

choose_ref_compiler(){
	echoFuncSeperator "choose_ref_compiler"
	echo -e "Current Reference Compiler: ${profile_color}${default_ref_compiler}${NC}"

	ref_compiler_list=(
		'Biber   ::Write bibliography for entries in AUXFILE to AUXFILE.bbl, along with a log file AUXFILE.blg'
		'BibTex  ::A bibtex replacement for users of biblatex'
		)

	count=0
    for index in "${ref_compiler_list[@]}"; do
        KEY="${index%%::*}"
        DES="${index##*::}"

        echo -e "[${count}] ${menu_color}${KEY}${NC} -> ${DES}"
        count=$((${count}+1))
    done   

    echo -e "Please choose references compiler (you can use the index number or compiler name, default is \"Biber\" if nothing chosen): "
	read -n1 ref_config
	echo ;	

	if [[ "${ref_config}" =~ ^[0-9]+$ ]] && [[ $((${ref_config})) -ge 0 ]] && [[ $((${ref_config})) -le $((${count}-1)) ]]; then
		count=0
	    for index in "${ref_compiler_list[@]}"; do
	        KEY="${index%%::*}"
	        KEY=${KEY//[[:space:]]/}
	        DES="${index##*::}"

	        if [[ "${ref_config}" == "${count}" ]] || [[ "${ref_config}" == "${KEY}" ]]; then
	        	default_ref_compiler="${KEY}"
	        	echo -e "[${count}] ${menu_color}${KEY}${NC} has been chosen."
	        	return
	        fi

	        count=$((${count}+1))
	    done 
	elif [[ "${default_ref_compiler}" != "" ]]; then
		default_ref_compiler="Biber"
		echo -e "[0] ${menu_color}${default_ref_compiler}${NC} has been chosen."
	else
		# do nothing
		echo -e "${ICON_WARN} Nothing changed."
		return ${WARN_CODE}
	fi
}

# choose proper encoding to parse your tex while compile/diff
choose_tex_encoding(){
	echoFuncSeperator "choose_tex_encoding"
	echo -e "Current .tex encoding: ${profile_color}${default_tex_encoding}${NC}"

	tex_encoding_list=(
		'ascii   ::A 7-bit character set containing 128 characters.'
		'utf8    ::A variable width character encoding capable of encoding all 1,112,064 valid code points in Unicode using one to four 8-bit bytes.'
		'unicode ::A computing industry standard for the consistent encoding.'
		)

	count=0
    for index in "${tex_encoding_list[@]}"; do
        KEY="${index%%::*}"
        DES="${index##*::}"

        echo -e "[${count}] ${menu_color}${KEY}${NC} -> ${DES}"
        count=$((${count}+1))
    done   

    echo -e "Please choose encoding used by *.tex: "
	read -n1 encoding_config
	echo ;	

	if [[ "${encoding_config}" =~ ^[0-9]+$ ]] && [[ $((${encoding_config})) -ge 0 ]] && [[ $((${encoding_config})) -le $((${count}-1)) ]]; then
		count=0
	    for index in "${tex_encoding_list[@]}"; do
	        KEY="${index%%::*}"
	        KEY=${KEY//[[:space:]]/}
	        DES="${index##*::}"

	        if [[ "${encoding_config}" == "${count}" ]] || [[ "${encoding_config}" == "${KEY}" ]]; then
	        	default_tex_encoding="${KEY}"
	        	echo -e "[${count}] ${menu_color}${KEY}${NC} has been chosen."
	        	return
	        fi

	        count=$((${count}+1))
	    done 
	elif [[ "${default_tex_encoding}" != "" ]]; then
		default_tex_encoding="utf8"
		echo -e "[0] ${menu_color}${default_tex_encoding}${NC} has been chosen."
	else
		# do nothing
		echo -e "${ICON_WARN} Nothing changed."
		return ${WARN_CODE}
	fi
}

compile(){
	echoFuncSeperator "Compiling with ${default_ref_compiler}"

	if [[ "$1" == "" ]]; then
		target_tex="${project_name}"
	else
		target_tex="$1"
		target_tex="${target_tex%%.tex}"
	fi

	# try to clean cache at the first version, or clean_cache after compilation for other version number to save time for each iteration
	if [[ "${tex_version_count}" == "" ]]; then
		clean_cache
	fi

	# output should be removed before each compilation
	# if [ -d "output" ]
	# then
	# 	rm -r "output"
	# fi

	compiler_str="${default_pdf_compiler} \"${target_tex}\""

	eval ${compiler_str}
	eval ${compiler_str}

	# generate nomenclature list
	makeindex "${target_tex}.nlo" -s nomencl.ist -o "${target_tex}.nls"

	if [[ "${default_ref_compiler}" == "Biber" ]]; then
		biber --output_safechars "${target_tex}"
	elif [[ "${default_ref_compiler}" == "BibTex" ]]; then
		bibtex "${target_tex}"
	fi
	
	eval ${compiler_str}
	eval ${compiler_str}

	killall ${compiler_str}

	mkdir -p "output"

	# target_tex.pdf is generated in the ./ dir, so remove any path prefix
	target_tex="${target_tex##*/}"

	mv "${target_tex}.pdf" "output/""${target_tex}.pdf"		
	open_file "output/""${target_tex}.pdf"		

	# version count: count+1 once completed
	if [[ "$1" == "" ]]; then
		compile_count
		backup_project
	fi

	# clean cache for the next compilation just for saving time
	clean_cache

	show_debug_msg "${ICON_ACCEPT} : Compile... done" ${ACCEPT_LEVEL}
}

compile_count(){
	echoFuncSeperator "compile_count"

	if [[ "${tex_version_count}" == "" ]]; then
		tex_version_count=0
	else
		tex_version_count=$((${tex_version_count}+1))
	fi

	show_debug_msg "${ICON_ACCEPT} : new version [${profile_color}${tex_version_count}${NC}] added." ${ACCEPT_LEVEL}
}

live_preview(){
	echoFuncSeperator "live_preview"

	if [[ "$1" == "" ]]; then
		target_tex="${project_name}"
	else
		target_tex="$1"
		target_tex="${target_tex%%.tex}"
	fi

	# try to clean cache at the first version, or clean_cache after compilation for other version number to save time for each iteration
	if [[ "${tex_version_count}" == "" ]]; then
		clean_cache
	fi

	lp_str="latexmk -pvc -pdf -pdflatex=${default_pdf_compiler} \"${target_tex}.tex\""
	eval ${lp_str}

	# move result to output
	mkdir -p "output"

	# target_tex.pdf is generated in the ./ dir, so remove any path prefix
	target_tex="${target_tex##*/}"

	mv "${target_tex}.pdf" "output/""${target_tex}.pdf"	

	# version count: count+1 once completed (only count the final version during live_preview)
	if [[ "$1" == "" ]]; then
		compile_count
		backup_project
	fi

	# clean cache for the next compilation just for saving time
	clean_cache

	show_debug_msg "${ICON_ACCEPT} : Live preview ended." ${ACCEPT_LEVEL}
}

show_biber_debugInfo(){
	biber -D "${project_name}"
}

backup_project(){
	# $1 -> src; $2 -> des;
	echoFuncSeperator "backup_project"

	if [ ! -d "${backup_folder}" ]
	then
		mkdir "${backup_folder}"
	fi

	rsync_except_list=(
		"${project_specified_conf_folder##*/}"
		"output"
		".DS_Store"
		)

	rsync_str="rsync -a"
	count=0
    for index in "${rsync_except_list[@]}"; do
        KEY="${index%%::*}"
        DES="${index##*::}"

        rsync_str=${rsync_str}" --exclude=\"${KEY}\""

        count=$((${count}+1))
    done  

    rsync_str=${rsync_str}" . \"${backup_folder}/bak_${tex_version_count}\""
    eval ${rsync_str}

    show_debug_msg "${ICON_ACCEPT} : new backup added." ${ACCEPT_LEVEL}
}

tar_project_for_commit(){
	echoFuncSeperator "tar_project_for_commit"

	tar_except_list=(
		"${project_specified_conf_folder##*/}"
		"output"
		".DS_Store"
		)

	tar_str="tar"
	count=0
    for index in "${tar_except_list[@]}"; do
        KEY="${index%%::*}"
        DES="${index##*::}"

        tar_str=${tar_str}" --exclude=\"${KEY}\""

        count=$((${count}+1))
    done  

    if [ ! -d "${backup_folder}" ]
    then
    	mkdir "${backup_folder}"
	fi

    tar_str=${tar_str}" -zcvf \"output/${project_name}.tgz\" ."
    eval ${tar_str}

    show_debug_msg "${ICON_ACCEPT} : the tar file has been created for commit." ${ACCEPT_LEVEL}
}

list_backup(){
	# find all current .tex and the recent modification time
	current_except_list=(
		"${project_specified_conf_folder##*/}"
		"output"
		)
	current_list_str="find \"${project_path}\" -type d"

	count=0
    for index in "${current_except_list[@]}"; do
        KEY="${index%%::*}"
        DES="${index##*::}"

        current_list_str=${current_list_str}" -name \"${KEY}\" -prune"

        count=$((${count}+1))
    done  
    current_list_str=${current_list_str}" -o -type f -iname '*.tex' -print0 | xargs -0 stat -f '%Sm %N,'"
    local current_list=`eval "${current_list_str}"`

	# sort list
	IFS=$',' 
	current_list=($(sort <<<"${current_list[*]}"))
	unset IFS

	# as sorted, the last one has the mostly recent modification time
	last_item=${current_list[$((${#current_list[@]}-1))]//*[[:space:]]\///}

    current_ver_time=`date -r "${last_item}" '+%Y-%m-%d %H:%M:%S'`
    current_ver_timestamp=`date -r "${last_item}" '+%s'`

    echo -e "${grey_time}Files in current version: ${NC}"
    # list all
    for index in "${!current_list[@]}"; do
        KEY=${current_list[index]//*[[:space:]]\///}
        KEY_time=`date -r "${KEY}" '+%Y-%m-%d %H:%M:%S'`

        KEY=${KEY##*\/}
        if [[ ${index} == $((${#current_list[@]}-1)) ]]; then
        	echo -e "[${index}] ${notify_color}${KEY_time}${NC} ${KEY}"
        else
        	echo -e "${grey_time}[${index}] ${KEY_time} ${KEY}${NC}"
        fi
    done  

    # list all backups
	lb_except_list=(
		"${project_specified_conf_folder##*/}"
		)

	lb_str="find \"${backup_folder}\" -type d -depth 1"
	count=0
    for index in "${lb_except_list[@]}"; do
        KEY="${index%%::*}"

        lb_str=${lb_str}" -not -iname \"${KEY}\""

        count=$((${count}+1))
    done  
    lb_str=${lb_str}" -print0 | xargs -0 stat -f '%Sm %N,' | sort"
	local bak_list=`eval "${lb_str}"`

	# sort list
	IFS=$',' 
	bak_list=($(sort <<<"${bak_list[*]}"))
	unset IFS

    # find mostly recent diff version
    candidate_diff=""
    for index in "${!bak_list[@]}"; do
        KEY="${bak_list[index]//*[[:space:]]\///}"
        KEY_time=`date -r "${KEY}" '+%Y-%m-%d %H:%M:%S'`
        KEY_timestamp=`date -r "${KEY}" '+%s'`

        KEY=${KEY##*\/}
		
        item_str=""
        if [[ ${index} == 0 ]]; then
        	item_str="Available history versions: "
        else
        	item_str="                            "
        fi

        item_str=${item_str}"[${KEY##*_}] ${profile_color}${KEY}${NC} " 

	    if [[ ${KEY_timestamp} -ge ${current_ver_timestamp} ]]; then
			# bak has no changes vs. the current version
			item_str=${item_str}"${grey_time}${KEY_time} <nothing changed>${NC}"
		else
			item_str=${item_str}"${highlight_time}${KEY_time}${NC}"

			candidate_diff=${KEY##*_} 
		fi 

		echo -e "${item_str}"
    done  
  
    echo -e "Current version modified time: ${notify_color}${current_ver_time}${NC}"
    echo -e "Recent changed version: ${profile_color}${candidate_diff}${NC}"

	eval "$1=\"${candidate_diff}\""
}

# $1 -> live_OnOff
diff_file(){
	echoFuncSeperator "diff_file"

	if [[ "${tex_version_count}" == "" ]]; then
		show_debug_msg "${ICON_ERR} : No historical version."	${ERR_LEVEL}
		return ${ERR_CODE}		
	else
		candidate_diff=''
		list_backup candidate_diff

		echo -e "Please choose a version to compare (by default use the most recent version ${highlight_time}${candidate_diff}${NC}):"
		# read -n1 diff_version
		read diff_version
		echo ;

		if [[ "${diff_version}" =~ ^[0-9]+$ ]] && [[ $((${diff_version})) -ge 0 ]] && [[ $((${diff_version})) -le $((${tex_version_count})) ]]; then
			old_tex="${backup_folder}/bak_${diff_version}/${project_name}.tex"
		elif [[ "${diff_version}" == "" ]] && [[ ! "${candidate_diff}" == "" ]]; then
			# default use the last modified one
			diff_version=$((${candidate_diff}))
			old_tex="${backup_folder}/bak_$((${candidate_diff}))/${project_name}.tex"
		elif [[ "${candidate_diff}" == "" ]]; then
			show_debug_msg "${ICON_ERR} : Cannot find the last modified version." ${ERR_LEVEL}
			return ${ERR_CODE}
		else
			show_debug_msg "${ICON_ERR} : Invalid version No. ${profile_color}${diff_version}${NC}" ${ERR_LEVEL}
			return ${ERR_CODE}
		fi

		show_debug_msg "${ICON_ACCEPT} : Chosen diff version: ${highlight_time}${diff_version}${NC}" ${ESSENTIAL_LEVEL}

		# diff now
		if [[ -f "${old_tex}" ]]; then
			diff_tex="${backup_folder}/last_diff.tex"
			# latexdiff old.tex new.tex > diff.tex
			latexdiff --encoding="${default_tex_encoding}" --flatten "${old_tex}" "${project_name}.tex" > "${diff_tex}"

			if [[ $1 == true ]]; then
				local compile_str="live_preview \"${diff_tex}\""
				eval "${compile_str}"
			else
				compile "${diff_tex}"
			fi			

			echo -e "recent diff_version: ${profile_color}${diff_version}${NC}"
		else
			show_debug_msg "${ICON_ERR} : the file ${profile_color}${old_tex}${NC} is not found." ${ERR_LEVEL}
			return ${ERR_CODE}
		fi
	fi
}

diff_file_live(){
	diff_file true
}

close_file(){
	echoFuncSeperator "close_file"
	killall Skim

	show_debug_msg "${ICON_ACCEPT} : the pdf file has been closed." ${ACCEPT_LEVEL}
}

open_file(){
	echoFuncSeperator "open_file"

	if [[ "$1" == "" ]]; then
		target_file="output/""${project_name}.pdf"
	else
		target_file="$1"
	fi

	if [ -f "${target_file}" ]
	then
		open  -a skim "${target_file}"
	else
		show_debug_msg "${ICON_ERR} : No file found!" ${ERR_LEVEL}
		return ${ERR_CODE}
	fi
}

open_output_dir(){
	echoFuncSeperator "open_output_dir"
	if [ -d "${project_path}/output" ]
	then
		open  -a Finder "${project_path}/output"
	else
		show_debug_msg "${ICON_ERR} : No output dir found! Open project dir instead." ${ERR_LEVEL}
		open  -a Finder "${project_path}"

		return ${ERR_CODE}
	fi
}

# should rename all backup as well
rename(){
	echoFuncSeperator "rename"

	clean_cache

	# find a file then rename (only need to rename the main *.tex file)
	if [ -f "${project_name}.tex" ]
	then 
		previous_name="${project_name}"
		echo "Please input the new project name to rename (name of .tex file without .tex):"
		read new_name

		if [[ "${new_name}" != "" ]]; then
			if [[ "${project_name}" != "${new_name}" ]]; then
				mv "${project_name}.tex" "${new_name}.tex"

				# try to rename previous result (rename the generated .pdf file in previous running)
				if [ -f "output/""${project_name}.pdf" ]
				then
					mv "output/""${project_name}.pdf" "output/""${new_name}.pdf"
				fi

				# write new configuration to profile file
				project_name="${new_name}"
				echo "project_path=\"${project_path}\"" > "${profile_path}"
				echo "project_name=\"${project_name}\"" >> "${profile_path}"

				# clean files generated by previous project
				find "${project_path}" -type f -maxdepth 1 -iname "${previous_name}.*" -print0 | xargs -0 rm						
			fi

			if [[ "${project_path}" != "${dir_namePathOnly}/${new_name}" ]]; then
				# then rename the project folder
				dir_nameWithoutPath=${project_path##*/}
				dir_namePathOnly=${project_path%/*}


				mv "${project_path}" "${dir_namePathOnly}/${new_name}"
				project_path="${dir_namePathOnly}/${new_name}"	

				show_debug_msg "${ICON_ACCEPT} : the project has been renamed as \"${profile_color}${new_name}${NC}\"." ${ACCEPT_LEVEL}	
			fi

			updateConfig
		fi
	else
		show_debug_msg "${ICON_ERR} : No main *.tex found, please specify the main .tex file." ${ERR_LEVEL}
		tryAutoFindMainTex
	fi
}

countPDFWords(){
	if [ -f "output/""${project_name}.pdf" ]
	then
		text="$(pdftotext "output/""${project_name}.pdf" - )"
		
		if [[ ${countExcludeRef} == true ]]; then
			text=${text%REFERENCES*}
		fi
		if [[ ${showTextForWordsCount} == true ]]; then
			echo -e "\n\033[34m**********[countPDFWords]**********${NC}"
			echo $text
			echo -e "\033[34m**********[countPDFWords]**********${NC}\n"
		fi
		
		wordsCount=$(echo ${text} | wc -w)
		wordsCount=${wordsCount//[[:space:]]/}
		echo -e "Last output: \033[31m${project_name}.pdf${NC} has \033[34m${wordsCount}${NC} words."
	fi
}

countingWordsConfig(){
	echo -e "Exclude references for words count? (\033[1;32my/n${NC})"
	read -n1 config
	echo ;	
	if [[ "${config}" == "y" ]] || [[ "${config}" == "Y" ]]; then
		countExcludeRef=true
	elif [[ "${config}" == "n" ]] || [[ "${config}" == "N" ]]; then
		countExcludeRef=false
	fi	

	echo -e "Show text for words count? (\033[1;32my/n${NC})"
	read -n1 config
	echo ;	
	if [[ "${config}" == "y" ]] || [[ "${config}" == "Y" ]]; then
		showTextForWordsCount=true
	elif [[ "${config}" == "n" ]] || [[ "${config}" == "N" ]]; then
		showTextForWordsCount=false
	fi	

	show_debug_msg "${ICON_ACCEPT} : new config for countingWords added." ${ACCEPT_LEVEL}		
}

install_package(){
	echoFuncSeperator "install_package"
	echo "Please input the package name to install (without .sty):"
	read package_name
	if [ "${package_name}" = "" ]
	then
		return
	else
		cat "${latex_package_profile_path}"

		sudo tlmgr install "${package_name}"

		echo -e "Install result code: $?"

		if [[ "$?" == "0" ]]; then
			# success
			echo "${package_name}" >> "${latex_package_profile_path}"
			show_debug_msg "${ICON_ACCEPT} : \"${profile_color}${package_name}${NC}\" has been installed." ${ACCEPT_LEVEL}
		else
			show_debug_msg "${ICON_ERR} : \"${profile_color}${package_name}${NC}\" failed to install." ${ERR_LEVEL}
		fi		
	fi	
}

project_display_switch(){
	if [[ ${Project_switch} == "1" ]]; then
		Project_switch="0"
	else
		Project_switch="1"
	fi
}

helper_display_switch(){
	if [[ ${Helper_switch} == "1" ]]; then
		Helper_switch="0"
	else
		Helper_switch="1"
	fi
}

error_tips_switch(){
	if [[ ${error_tips_enable} == true ]]; then
		error_tips_enable=false
	else
		error_tips_enable=true
	fi
}

error_tips(){
	if [[ ${error_tips_enable} == true ]]; then
		echo "*******************"
		echo -e "Tips: \nError caused by references: \nCheck special characters {\033[34m$ _${NC}} or empty bibtex entries in .bib file."
		echo -e "Example for installing unknown package:\n      \033[1;32msudo tlmgr repository http://ctan.org/tex-archive/macros/latex/contrib/ install cookybooky${NC}"
		echo -e "Debug with argument: <DEBUG_LEVEL 0 ~ 5>, e.g. this_script.sh 5"
		echo "*******************"
	fi
}

#   -------------------------------
#   UI functions
#   -------------------------------

enable_color_theme(){
  NC='\033[0m'  # the end
  
  # foreground colours
  BLACK='\033[0;30m'
  RED='\033[0;31m'
  D_RED='\033[1;31m'
  GREEN='\033[0;32m'
  D_GREEN='\033[1;32m'
  YELLOW='\033[0;33m'
  D_YELLOW='\033[2;33m'
  BLUE='\033[0;34m'
  MAGENTA='\033[0;35m'
  CYAN='\033[0;36m'
  LIGHT_GRAY='\033[0;37m'
  D_GRAY='\033[2;37m'
  DARK_GRAY='\033[0;90m'
  LIGHT_RED='\033[0;91m'
  LIGHT_GREEN='\033[0;92m'
  LIGHT_YELLOW='\033[0;93m'
  LIGHT_BLUE='\033[0;94m'
  LIGHT_MAGENTA='\033[0;95m'
  LIGHT_CYAN='\033[0;96m'
  WHITE='\033[0;97m'
  D_WHITE='\033[1;97m'
}

default_theme(){
    default_color="$D_WHITE"  # white color

    title_window_color="$GREEN"
    title_name_color="$RED"

    profile_color="$BLUE"
    menu_color="$D_GREEN"
    fun_seperator_color="$D_GRAY"
    func_name_color="$D_GRAY"
    status_seperator_color="$GREEN"

    notify_profile_color="$WHITE"
    notify_color="$D_YELLOW"

    err_msg_color="$D_RED"

    highlight_time="$MAGENTA"
    grey_time="$D_GRAY"

    ICON_ACCEPT="✅  "
    ICON_ERR="❌  "
	ICON_WARN="⚠️  "

    ACCEPT_CODE=0
    ERR_CODE=1
    WARN_CODE=2

    DEBUG_LEVEL_MAX=5
    DEBUG_LEVEL_MIN=1

    # msg_level:
	# err -> 0 warn -> 1 accept ->2 normal -> 3
	ERR_LEVEL=0
	ESSENTIAL_LEVEL=0
	WARN_LEVEL=1
	ACCEPT_LEVEL=2
	NORMAL_LEVEL=3
}

echoFuncSeperator(){
	if [[ "${DEBUG_LEVEL}" -ge "${DEBUG_LEVEL_MAX}" ]]; then
		echo -e "\n"
	    constructSeperator "[$1]" "*" "${fun_seperator_color}"
	fi    
}

# $1 -> character; $2 -> repeating times
repeatEcho(){
	seq -f "$1" -s '' $2; echo
}

constructSeperator(){
    terminalWidth=$(tput cols)
    windowWidth=${terminalWidth}
    instructionTitle=$1 

    if [[ ${windowWidth} -le $((${#sh_name}+${#sh_ver}+7)) ]]; then
        windowWidth=$((${#sh_name}+${#sh_ver}+7))
    fi

    if [[ ${windowWidth} -le $((${#instructionTitle})) ]]; then
        windowWidth=$((${#instructionTitle}+2))
    fi

    lengthSeperator=$((windowWidth-${#instructionTitle}))
    tmpSeperator=$(repeatEcho "$2" $lengthSeperator)
    insertPos=$(($lengthSeperator/2))
    
    if [[ "$3" == "" ]]; then
        color="${default_color}"
    else
        color=$3
    fi

    if [[ "$2" != " " ]]; then
        echo -e "${color}${tmpSeperator:0:$insertPos}${NC}${func_name_color}${instructionTitle}${NC}${color}${tmpSeperator:$insertPos:${#tmpSeperator}}${NC}"
    else
        tmpSeperator=${tmpSeperator/#[[:space:]]/*}
        tmpSeperator=${tmpSeperator/%[[:space:]]/*}
        echo -e "${color}${tmpSeperator:0:$insertPos}${NC}${title_name_color}${instructionTitle}${NC}${color}${tmpSeperator:$insertPos:${#tmpSeperator}}${NC}"
    fi
}

clean_terminal(){
	# clean if no debug needed and no error or warn
	if [[ $((${hasError})) == 0 ]] && [[ $((${hasWarn})) == 0 ]] && [[ "${DEBUG_LEVEL}" == "" ]];then
		clear && printf '\e[3J'
	fi
}

showErrWarnStats(){
	echoFuncSeperator "showErrWarnStats"
	if [[ ${hasError} -gt 0 ]]; then
		show_debug_msg "${ICON_ERR} : ${hasError} errors found." ${ERR_LEVEL}
	fi

	if [[ ${hasWarn} -gt 0 ]]; then
		show_debug_msg "${ICON_WARN} : ${hasWarn} warn found." ${ERR_LEVEL}
	fi

	# reset error and warn report
	hasError=0
	hasWarn=0
}

quit(){
	updateRunHistory "${ICON_ACCEPT}[${option}]: quit... done."
    echo -e "${notify_color}<${run_history}>${NC}"

    exit
}

showAppTitle(){
    constructSeperator "" "*" "${title_window_color}"
    constructSeperator " ${sh_name} v${sh_ver} " " " "${title_window_color}"
    constructSeperator " ${sh_time} " " " "${title_window_color}"
    constructSeperator "" "*" "${title_window_color}"
}

# hide username in path
anonymisePath(){
	local path="$1"

	if [[ "${path:0:1}" == "/" ]]; then
		local output=`echo "${path}" | sed 's/^\/[a-zA-z]*\/[a-zA-z]*\//~\//g'`

		eval "$2=\"${output}\""
	fi
}

showProfile(){
    echoFuncSeperator "Profile"

    arrayProfile=(
        # VAR::Description
        "${project_path}::Current directory"
        "${project_name}::Current Project"
        "${default_pdf_compiler}::Current pdf Compiler"
        "${default_ref_compiler}::Current Reference Compiler"
        "${default_tex_encoding}::Current encoding used by *.tex"
        "${countExcludeRef}::Words counting config: exclude references="
        # "${diff_version}::Recent diff version"
        "${tex_version_count}::Current version Number"
        # "${project_specified_config}::Project specified config"
        )

    for index in "${arrayProfile[@]}"; do
        KEY="${index%%::*}"
        DES="${index##*::}"

        anonymisePath "${KEY}" KEY
        echo -e "${DES}: ${profile_color}${KEY}${NC}"
    done   

    # if output.pdf exist, show words counting result.
	countPDFWords

    constructSeperator "" "-" "${status_seperator_color}"
}

showMenu(){
    arrayMenu=(
        # KEY::Function::Description::Menu_level::CAT_ENABLE_DISPLAY
		# if [[ "${option}"== "" ]]; then
		#     echo "Enter"
		# fi
		
		# project
		'            ::                        :: Project_1                                                               :: 0 :: 1 '
		'1           :: project_display_switch :: Project                                                                 :: 0 :: 0 '
		'q      or Q :: quit                   :: Exit (Ctrl+C)                                                           :: 0 :: 1 '
		'c      or C :: choose_project         :: Choose another working project                                          :: 0 :: 1 '
		'r      or R :: rename                 :: Rename your project                                                     :: 0 :: 1 '
		'o      or O :: open_file              :: Re-open the result                                                      :: 0 :: 1 '
		'p      or P :: open_output_dir        :: Open the output dir                                                     :: 0 :: 1 '

		'a      or A :: live_preview           :: PDF live preview                                                        :: 0 :: 1 '
		'Enter  or   :: compile                :: Recompile using previous compiler                                       :: 0 :: 1 '
		'k      or K :: choose_pdf_compiler    :: Choose pdf compiler                                                     :: 1 :: 1 '
		'l      or L :: choose_ref_compiler    :: Choose references compiler                                              :: 1 :: 1 '
		'z      or Z :: tar_project_for_commit :: Compress the source project for commit (without compiled output)        :: 0 :: 1 '
		'x      or X :: diff_file              :: Differ from old versions                                                :: 0 :: 1 '
		'y      or Y :: diff_file_live         :: Differ from old versions (in Live mode)                                 :: 0 :: 1 '

		# helper
		'            ::                        :: Helper_2                                                                :: 0 :: 0 '
		'2           :: helper_display_switch  :: Helper                                                                  :: 0 :: 0 '
		'm      or M :: tryAutoFindMainTex     :: Specify the main *.tex file for the project (in case of multiple *.tex) :: 0 :: 1 '
		'd      or D :: clean_cache            :: Clean cache and dump files                                              :: 0 :: 1 '
		's      or S :: deep_clean_cache       :: Deep clean your project, this option can remove biber cache             :: 0 :: 1 '
		'h      or H :: delete_all_backup      :: Delete all backups                                                      :: 0 :: 1 '
		'b      or B :: show_biber_debugInfo   :: Display debug info for .bib file                                        :: 0 :: 1 '
		'w      or W :: countingWordsConfig    :: Configure wordsCount                                                    :: 0 :: 1 '
		'e      or E :: choose_tex_encoding    :: Choose encoding used by *.tex (default utf8)                            :: 0 :: 1 '
		'i      or I :: install_package        :: Install a missing package                                               :: 0 :: 1 '
		'?           :: error_tips_switch      :: Help                                                                    :: 0 :: 1 '
        )

    count=0
    local subcount=0
    PRE_MENU_LEVEL=0
    menu_prefix="[0]"
    for index in "${arrayMenu[@]}"; do
        KEY="${index%%::*}"
        KEY_1="${KEY%%or*}"
        KEY_2="${KEY##*or}"
        KEY_1=${KEY_1//[[:space:]]/}
        KEY_2=${KEY_2//[[:space:]]/}

        FUN="${index#*::}"
        FUN="${FUN%%::*}"     
        FUN=${FUN//[[:space:]]/}

        PRE_DES="${DES}"
        DES="${index#*::}"
        DES="${DES#*::}"
        DES="${DES%%::*}"

        # MENU_LEVEL="${index##*::}"
        MENU_LEVEL="${index#*::}"
        MENU_LEVEL="${MENU_LEVEL#*::}"
        MENU_LEVEL="${MENU_LEVEL#*::}"
        MENU_LEVEL="${MENU_LEVEL%%::*}"
        MENU_LEVEL=${MENU_LEVEL//[[:space:]]/}
        MENU_LEVEL=$((${MENU_LEVEL}))

        ENABLE_DISPLAY="${index##*::}"
        ENABLE_DISPLAY=${ENABLE_DISPLAY//[[:space:]]/}

        if [[ "${KEY//[[:space:]]/}" == "" ]]; then
        	menu_prefix="[0]"

        	DES="${DES//[[:space:]]/}"
        	KEY="${DES##*_}"
        	DES="${DES%%_*}"
        	eval "cat_status=\"\${${DES}_switch}\""

        	if [[ "${cat_status}" != "" ]]; then
        		CAT_ENABLE_DISPLAY="${cat_status}"
        	else
        		CAT_ENABLE_DISPLAY="${index##*::}"
		        CAT_ENABLE_DISPLAY=${CAT_ENABLE_DISPLAY//[[:space:]]/}

		        eval "${DES}_switch=\"${CAT_ENABLE_DISPLAY}\""
        	fi

        	if [[ "${CAT_ENABLE_DISPLAY}" == "1" ]]; then
        		echo -e "${fun_seperator_color}+ ${DES} (${KEY})${NC}"
        	else
        		echo -e "${fun_seperator_color}- ${DES} (${KEY})${NC}"
        	fi
        elif [[ ! "${FUN}" == "" ]] && [[ "${CAT_ENABLE_DISPLAY}" == "1" ]] && [[ "${ENABLE_DISPLAY}" == "1" ]] && [[ "${PRE_DES}" != "${DES}" ]]; then
	        # sed slows down the speed, but flexible
	        if [[ ${MENU_LEVEL} -gt ${PRE_MENU_LEVEL} ]]; then
	        	menu_prefix=${menu_prefix}
	        	menu_prefix=${menu_prefix//]/.0]}
	        elif [[ ${MENU_LEVEL} -lt ${PRE_MENU_LEVEL} ]]; then
	        	pre_count=`echo "${menu_prefix}" | sed  's/.*[\[|\.]\([0-9]*\)\.[0-9]*]$/\1/g'`	
	        	count=$((${pre_count}+1))

	        	menu_prefix=`echo "${menu_prefix}" | sed  's/\(.*[\[|\.]\)\([0-9]*\.[0-9]*\)]$/\1/g'`
	        	menu_prefix=${menu_prefix}"${count}]"
	        else
	        	pre_count=`echo "${menu_prefix}" | sed  's/.*[\[|\.]\([0-9]*\)]$/\1/g'`
	        	count=$((${pre_count}+1))
	        	
	        	menu_prefix=`echo "${menu_prefix}" | sed  's/\(.*[\[|\.]\)\([0-9]*\)]$/\1/g'`
	        	menu_prefix=${menu_prefix}"${count}]"
	        fi

	        local shortcut="${menu_color}${KEY_1}${NC}"
	        if [[ ${KEY_2} != "" ]]; then
	        	shortcut="${shortcut} or ${menu_color}${KEY_2}${NC}"
	        fi

	        if [[ ${MENU_LEVEL} == 0 ]]; then
	        	menu_indent=""
	        else
	        	menu_indent=$(repeatEcho " " $((3*${MENU_LEVEL})))
	        fi
	        
	        echo -e "  ${menu_indent}${menu_prefix} ${shortcut} -> ${FUN} -> ${DES}"

	        PRE_MENU_LEVEL=${MENU_LEVEL}        	
        fi
    done 

    error_tips   

    showRunHistory  
    
    read -n1 option
    echo ;

    clean_terminal

    if [[ "${option}" == "" ]]; then
    	option="Enter"
    	echo ${option}
    fi

    # not necessary if Skim enable auto-reload
    # defaults write -app Skim SKAutoReloadFileUpdate -boolean true 
    # close_file
    
    # read -s -n1 -p "Hit a key " keypress
    # -s 选项意味着不打印输入.
    # -n N 选项意味着只接受N个字符的输入.
    # -p 选项意味着在读取输入之前打印出后边的提示符.
    
    final_option=""
    for index in "${arrayMenu[@]}"; do
        KEY="${index%%::*}"
        KEY_1="${KEY%%or*}"
        KEY_2="${KEY##*or}"
        KEY_1=${KEY_1//[[:space:]]/}
        KEY_2=${KEY_2//[[:space:]]/}
        KEY=${KEY//[[:space:]]/}

        FUN="${index#*::}"
        FUN="${FUN%%::*}"     
        FUN=${FUN//[[:space:]]/}

        DES="${index#*::}"
        DES="${DES#*::}"
        DES="${DES%%::*}"

        if [[ ! "${KEY}" == "" ]]; then
			if [[ "$option" = "${KEY_1}" ]] || [[ "$option" = "${KEY_2}" ]]; then
	            final_option="${FUN}"
	        fi
        fi
    done  

    if [[ "${final_option}" != "" ]]; then
        if [[ "${final_option}" != "quit" ]]; then
            echo -e "${notify_color}<${final_option}... begin.>${NC}"  
            updateRunHistory "${ICON_WARN}[${option}]: ${final_option}... uncompleted."
        fi 

        eval ${final_option}  

        EXIT_CODE=$?

        case $EXIT_CODE in
			${ACCEPT_CODE})
				updateRunHistory "${ICON_ACCEPT}[${option}]: ${final_option}... done."
				;;
			${ERR_CODE})
				updateRunHistory "${ICON_ERR}[${option}]: ${final_option}... fail."
				;;
			${WARN_CODE})
				updateRunHistory "${ICON_WARN}[${option}]: ${final_option}... warn."
				;;
			*)
				updateRunHistory "${ICON_ERR}[${option}]: ${final_option}... unknown fail."
				;;
		esac
    else
        updateRunHistory "${ICON_ERR}[${option}]: Invalid option."
    fi   

    echo -e "${notify_color}<${run_history}>${NC}"
}

showRunHistory(){
    constructSeperator "" "-"
    echo -e "Last run history: ${profile_color}${run_history}${NC}"
    constructSeperator "" "-"
}

trim_sh_name(){
    local tmp=$1

    if [[ "$2" != "" ]]; then
        tmp=${tmp//[[:space:]]/$2}
    fi   
    echo "$tmp"
}

init(){
	# shell for compilation of latex file with citation 
	sh_name="Build latex projects"
    sh_ver="1.0.0.1"
    sh_time="08/02/2018 12:13:00"

    # name for files in project folder, e.g. "*.profile"
    sh_name_extra=$(trim_sh_name "${sh_name}" "_")

	# shell path
	shell_path=$(dirname "${0}")"/"
	profile_folder=${shell_path}"profile/"


	# profile path
	profile_path=${profile_folder}"${sh_name_extra}.profile"
	latex_package_profile_path=${profile_folder}"latex_package.profile"

	# write new configuration to profile file
    defaultConfigList=(
        # name::value::Description
        'project_path::$HOME"" ::project path'
        'project_name::""'
        'default_pdf_compiler::"pdflatex"'
        'default_ref_compiler::"Biber"'
        'default_tex_encoding::"utf8"'
        'countExcludeRef::true'
        'showTextForWordsCount::false'
        'run_history::                ::run history'
        )

    # project specified configuration
    ProjectSpecifiedConfigList=(
        # name::value::Description
        'default_pdf_compiler::"pdflatex"'
        'default_ref_compiler::"Biber"'
        'default_tex_encoding::"utf8"'
        'tex_version_count::""'
        )

	error_tips_enable=false

	hasError=0
	hasWarn=0

	enable_color_theme

	default_theme

	showAppTitle

	load_project

	show_debug_msg "${ICON_ACCEPT} : the application is ready to use." ${ACCEPT_LEVEL}

	clean_terminal
}

main(){
	if [[ "$1" =~ ^[0-9]+$ ]] && [[ $(($1)) -gt 0 ]];then
		DEBUG_LEVEL=$(($1))
	fi

	init

	until [ "$option" = "q" ]
	do
		# clear previous running
		clean_terminal

		showErrWarnStats

		showAppTitle

		showProfile
		
		showMenu
	done
}

# DEBUG_LEVEL (> 0): $1 -> "5"
main $1
