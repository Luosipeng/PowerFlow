function gen_idx()
    #发电机索引
    ##===================================idx=========================##
    Gen_connected_element=2;#电压
    Gen_inservice=3;#潮流初始值（标幺值）
    Gen_controlmode=5;
    Gen_power_rating=7;#相数
    Gen_apparent_power_rating=9;#最小需求指数
    Gen_voltage=11;#连续额定容量
    return Gen_connected_element,Gen_inservice,Gen_controlmode,Gen_power_rating,Gen_apparent_power_rating,Gen_voltage
end