#!/bin/bash

container_cmd="docker run -v=$(pwd):/kikit -w=/kikit --rm yaqwsx/kikit:v1.3.0-v7"
container_cmd_draw="docker run -v=$(pwd):/kikit -w=/kikit --rm --entrypoint pcbdraw yaqwsx/kikit:v1.3.0-v7"

# Images
echo "Drawing image files"
mkdir -p images
for name in "pcb" "plate" "bottom"
do
	for option in "$name"/*/
	do
		short_option="$(basename "$option")"
		file="$(find $option -type f -name '*.kicad_pcb')"
		${container_cmd_draw} plot --style set-blue-hasl "$file" images/"$name"_"$short_option".png >> /dev/null
		${container_cmd_draw} plot --style set-blue-hasl --side back "$file" images/"$name"_"$short_option"_back.png >> /dev/null
	done
done

# Gerbers
echo "Generating gerbers"
mkdir -p gerbers
for name in "pcb" "plate" "bottom"
do
	prefix="case"
	if [[ "$name" == "pcb" ]]; then 
		prefix="pcb"
	fi
	mkdir -p gerbers/"$prefix"
	for option in "$name"/*/
	do
		if [[ "$name" == "plate" ]] && [[ "$option" =~ ^.*\/laser_plastic.*$ ]]; then # Solid bottoms/plates may be a choice
			continue
		fi
		short_option="$(basename "$option")"
		file="$(find $option -type f -name '*.kicad_pcb')"
		${container_cmd} fab jlcpcb --no-assembly "$file" gerbers/"$name"_"$short_option" --no-drc
		mv gerbers/"$name"_"$short_option"/gerbers.zip gerbers/"$prefix"/"$name"_"$short_option"_gerbers.zip
		rm -r gerbers/"$name"_"$short_option"
	done
done

zip -jr gerbers/case/gerber_case_files gerbers/case/

# Plate/bottom dxf files
echo "Generating case DXF files"
mkdir -p dxf
for name in "plate" "bottom"
do
for option in "$name"/*/
	do
		if [[ ! "$option" =~ ^.*\/laser.*$ ]]; then
			continue
		fi
		short_option="$(basename "$option")"
		file="$(find $option -type f -name '*.kicad_pcb')"
		file_name=$(basename "$file" .kicad_pcb)
		${container_cmd} export dxf "$file" dxf/"$name"_"$short_option"
		mv dxf/"$name"_"$short_option"/"$file_name"-EdgeCuts.dxf dxf/"$name"_"$short_option".dxf
		rm -r dxf/"$name"_"$short_option"
	done
done

zip -jr dxf/laser_case_files dxf/
	