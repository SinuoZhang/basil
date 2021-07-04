
# ---------------------------------------------------------------
# Copyright (c) SILAB ,  Institute of Physics, University of Bonn
# ---------------------------------------------------------------
#
#   This script creates Vivado projects and bitfiles for the supported hardware platforms.
#
#   Clone the SiTCP repository as described in the readme file
#   Start vivado in tcl mode by executing:
#       vivado -mode tcl -source run.tcl
#

set basil_dir [exec python -c "import basil, os; print(str(os.path.dirname(os.path.dirname(basil.__file__))))"]
set firmware_dir [exec python -c "import os; print(os.path.dirname(os.getcwd()))"]
set include_dirs [list $basil_dir/basil/firmware/modules $basil_dir/basil/firmware/modules/utils $firmware_dir $firmware_dir/IP/synth $firmware_dir/IP]
file mkdir output reports

proc read_design_files {option part} {
    global firmware_dir

    if {$option == "10G"} {
        generate_ip_cores "ten_gig_eth_pcs_pma" $part
        add_files -norecurse $firmware_dir/IP/ten_gig_eth_pcs_pma.xci

        read_edif $firmware_dir/SiTCPXG/SiTCPXG_XC7K_128K_V1.edf
        read_verilog $firmware_dir/SiTCPXG/SiTCPXG_XC7K_128K_V1.v
        read_verilog $firmware_dir/SiTCPXG/TIMER_SiTCPXG.v
        read_verilog $firmware_dir/SiTCPXG/WRAP_SiTCPXG_XC7K_128K.v
    } else {
        read_edif $firmware_dir/SiTCP/SiTCP_XC7K_32K_BBT_V110.ngc
    }

    read_verilog $firmware_dir/src/kc705_10G.v
}

proc generate_ip_cores {name part} {
    global firmware_dir
    set ipname $name
    set xci_file $firmware_dir/IP/$name.xci

    create_project -force ipcore -part $part
    read_ip $xci_file
    upgrade_ip [get_ips *]
    generate_target -verbose -force all [get_ips]
    create_ip_run [get_files $xci_file]
    launch_runs $ipname\_synth_1 -jobs 12
    wait_on_run $ipname\_synth_1
    close_project
}

proc run_bit {part board xdc_file size option} {
    global firmware_dir
    global include_dirs

    create_project -force -part $part $board$option designs

    read_design_files $option $part

    read_xdc $firmware_dir/src/$xdc_file
    if {$option == "10G"} {
        read_xdc $firmware_dir/IP/synth/ten_gig_eth_pcs_pma.xdc
        read_xdc $firmware_dir/IP/synth/ten_gig_eth_pcs_pma_clocks.xdc        
    } else {
        read_xdc $firmware_dir/SiTCP.xdc
    }

    synth_design -top kc705_10G -include_dirs $include_dirs -verilog_define "$board=1" -verilog_define "SYNTHESIS=1" -verilog_define "$option=1"
    opt_design
    place_design
    phys_opt_design
    route_design
    report_utilization -file "reports/report_utilization_$board\_$option.log"
    report_timing_summary -file "reports/report_timing_$board\_$option.log"
    write_bitstream -force -file output/$board\_$option
    write_cfgmem -format mcs -size $size -interface SPIx4 -loadbit "up 0x0 output/$board\_$option.bit" -force -file output/$board\_$option
    close_project

    exec tar -C ./output -cvzf output/$board\_$option.tar.gz $board\_$option.bit $board\_$option.mcs
}


#
# Create projects and bitfiles
#

if {$argc == 0} {
# By default, all firmware versions are generated. You can comment the ones you don't need.
#       FPGA type           board name   constraints file  flash size  option
#run_bit xc7k325tffg900-2    KC705        kc705_10G.xdc     16          ""
run_bit xc7k325tffg900-2    KC705        kc705_10G.xdc     16          10G


# In order to build only one specific firmware version, the tun.tcl can be executed with arguments
} else {
    if {$argc == 8} {
        run_bit {*}$argv
    } else {
        puts "ERROR: Invalid args"
    }
}

exit
