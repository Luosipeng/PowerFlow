function gen_idx()
    #发电机索引
    ##===================================idx=========================##
    Gen_connected_element=5;#电压
    Gen_inservice=3;#潮流初始值（标幺值）
    Gen_controlmode=10;
    Gen_power_rating=7;#KW
    Gen_apparent_power_rating=8;#KVA
    Gen_voltage=6;#
    return Gen_connected_element,Gen_inservice,Gen_controlmode,Gen_power_rating,Gen_apparent_power_rating,Gen_voltage
end