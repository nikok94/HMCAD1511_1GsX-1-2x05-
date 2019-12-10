########################################################################
#
#
#

set root_dir [ file normalize [file dirname [info script]]/../ ]
set device "xc6slx16ftg256-2"
set prj_name "ADC1511_1000MHzX1_2"
set language "VHDL"

# Create project
create_project $prj_name -force $root_dir/prj

# Set the directory path for the new project
set proj_dir [get_property directory [current_project]]

# Set project properties
set obj [get_projects $prj_name]
set_property "part" $device $obj
set_property "target_language" "VHDL" $obj

########################################################################
# Sources
add_files -norecurse ../src/ADC1511_Dual_1GHzX2_Top.vhd
add_files -norecurse ../src/data_capture.vhd
add_files -norecurse ../src/clock_generator.vhd
add_files -norecurse ../src/QuadSPI_adc_250x4_module.vhd
add_files -norecurse ../src/trigger_capture.vhd
add_files -norecurse ../src/SPI_ADC_250x4/spi_adc_250x4_master.vhd
add_files -norecurse ../src/SPI_ADC_250x4/spi_byte_receiver.vhd
add_files -norecurse ../src/SPI_ADC_250x4/spi_byte_transceiver.vhd
add_files -norecurse ../src/HMCAD1511_v3_00/high_speed_clock_to_serdes.vhd
add_files -norecurse ../src/HMCAD1511_v3_00/HMCAD1511_x2_v1_00.vhd
add_files -norecurse ../src/HMCAD1511_v3_00/HMCAD1511_v3_00.vhd
add_files -norecurse ../src/HMCAD1511_v3_00/data_deserializer.vhd
add_files -norecurse ../src/blk_mem_gen_v7_3_0/mem_64_4096.xci
add_files -norecurse ../src/fifo_generator_v9_3_0/fifo_64_8.xci
add_files -norecurse ../src/fifo_generator_v9_3_2/async_fifo_64.xci


########################################################################
# UCF
add_files -fileset [current_fileset -constrset] -norecurse ../ucf/ADC1511_Dual_1GHzX2_constr.ucf
set_property target_constrs_file ../ucf/ADC1511_Dual_1GHzX2_constr.ucf [current_fileset -constrset]


#set_property SOURCE_SET sources_1 [get_filesets sim_1]
#add_files -fileset sim_1 -norecurse -scan_for_includes $root_dir/sim/const_package.vhd
#add_files -fileset sim_1 -norecurse -scan_for_includes $root_dir/sim/pci_arbt_module.vhd
#add_files -fileset sim_1 -norecurse -scan_for_includes $root_dir/sim/pci_host_module.vhd
#add_files -fileset sim_1 -norecurse -scan_for_includes $root_dir/sim/stream_pci_TB.vhd
#add_files -fileset sim_1 -norecurse -scan_for_includes $root_dir/sim/host_pc_module.vhd
#
#update_compile_order -fileset sim_1


