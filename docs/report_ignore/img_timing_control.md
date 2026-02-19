{ signal: [
  // Source Clocks (independent phases)
  { name:'clk',     		wave: 'P.............' },
  { name:'img_complition', 	wave: '0...1...0.....' },
  {name: 'img_cfg', 		wave: '2.....2.......', data: 'OLD_IMAGE_CFG NEW_IMGE_CFG'}, 
  { name:'img_ready',   	wave: '0......1..0...' },
  { name:'img_read',     	wave: '0........1....'},
  {name: 'img_data', 		wave: '2...x.....2...', data: 'OLD_IMAGE NEW_IMGE'},
],
  head: {
   text: 'IMG TRANS CONTROL FLOW',
   tick: 0,
 }
 ,"config" : {hscale : 2}
}

//============================================================================================

{ signal: [
  { name:'clk',		     					wave: 'P..........' },
 	['MAC',
     { name:'frame_data',	 					wave: 'x.2..0.2..0' , data: 'FRAME0 FRAEM1 FRAME2'}
    ],
  {},
  ['MSG_PARSER', 
  {name: 'cmd_analysis_comb', 				wave: 'x.2.0..2.0.'  ,data: 'W_CMD R_CMD'}, 
  { name:'sel_en_comb',   					wave: 'x.1.0..1.0.' },
  { name:'cmd_ack',     					wave: '0..1.0..1.0'},
   { name:'DATA',   						wave: '0.2..0.....' ,data: 'RDATA RDATA RDATA'},
   
  ],
   {},
   ['ADDR_SWLWCTION', 
 	 	{name: 'w_sel_en', 						wave: '0.2.0......'  	,data: 'REG_0 REG_X'}, 
  		{name:'r_sel_en',   					wave: '0......2.0.'		,data: 'REG_OFFSET_0 REG_X' },
  		{name:'tx_reg_read',   					wave: '0.......2.0' ,data: 'RDATA RDATA RDATA'},
  	 
  ],  
    {},
   ['RGF',
    	{ name:'W_reg_viewer',   				wave: '0.2.0......' ,data: 'RDATA'},
 	 	{name: 'w_sel_en', 						wave: '0.2.0......'  	,data: 'REG_0 '}, 
        { name:'offset_addr_en',   				wave: '0.2.0......' ,data: 'OFFSET_0'},
        { name:'RW_reg_0_real',   				wave: 'x..2.......' ,data: 'RDATA'},
        { name:'R_reg_viewer',   				wave: 'x..2.......' ,data: 'RDATA'},
    	{ name:'R_reg_seL',   					wave: 'x......2.0..' ,data: 'OFFSET_0'},
  ]
],
  head: {
   text: 'RX FRAME DATA TO PARSER AND ACK',
   tick: 0,
 }
 ,"config" : {hscale : 2}
}

//===============================================================================================
{ "signal": [
    	["Pixel_Mem",
    	{ "name": "clk",             	"wave": "p.............................." },
        { "name": "o_almost_full_w", 	"wave": "0....................1....0...." },
     	{ "name": "cycle_cnt",      	"wave": "2.2.2.2.2.2.2.2.2.2.2......2..." ,data: "0 1 2 3 0 1 2 3 0 1 2 3 0 1 2 3"},
    	{ "name": "pixel_pkt_load",  	"wave": "0......10......10...........10." },
    	{ "name": "o_rom_red[31:0]", 	"wave": "x......2.......2............2..", "data": "R0R1R2R3 R4R5R6R7 R8R9R10R11" },
        ],
       	{},
     	["Seq",
        { "name": "o_almost_full_w", 	"wave": "0....................1....0..." },
      	{ "name": "write_sub_pixel",	"wave": "x.......5.4.3.2.5.4.3......5..", "data": ["3", "2", "1", "0","3", "2", "1", "0"] },
   		{ "name": "i_fifo_temp",     	"wave": "x.......=.=.=.=.=.=.=......=..", "data": "R0R1R2R3 R1R2R3 R2R3 R3 R4R5R6R7 R5R6R7 R6R7 R7 R8R9R10R11" },
    	{ "name": "fifo_din",        	"wave": "........x=.=.=.=.=.=.=......=.", "data": ["R0", "R1", "R2", "R3","R4", "R5", "R6", "R7","R8"] },
  		],
       	{},
		["FIFO",
      		{ "name": "mem[0]",			"wave": "x........x....................", "data": ["R0"] },
         	{ "name": "mem[1]",			"wave": "x..........x=.................", "data": [ "R1"] },
         	{ "name": "mem[2]",			"wave": "x............x=...............", "data": [ "R2"] },
         	{ "name": "mem[3]",			"wave": "x..............x=.............", "data": [ "R3"] },
         	{ "name": "mem[4]",			"wave": "x................x=...........", "data": [ "R4"] },
         
  		],
],
  head: {
   text: 'FROM MEM TO FIFO FLOW',
   tick: 0,
 }
 ,"config" : {hscale : 1}
}
//===================================================================================================
{ signal: [
  { name:'clk',		     					wave: 'P................' },
 	['MAC',
     { name:'frame_data',	 				wave: 'x2..02..02..02..0' , data: 'FRAME0 FRAEM1 FRAME2 FRAM3'}
    ],
  {},
  ['MSG_PARSER', 
  {name: 'cmd_analysis_comb', 				wave: 'x2.0.2.0.2.0.2.0.'  ,data: 'Wpixel_CMD Wpixel_CMD Wpixel_CMD Wpixel_CMD'},
  { name:'cmd_ack',     					wave: '0.1.0.1.0.1.0.1.0'},
  { name:'DATA',   							wave: '02..02..02..02..0.' ,data: 'PIXEL_0 PIXEL_1 PIXEL_2 PIXEL_3'},
   
  ],
   {},
   ['PIXEL MEM', 
 	 	{name: 'write_pixel', 						wave: '0.1.0.1.0.1.0.1.0.'  	,data: 'REG_0 REG_X'}, 
    	  {name: 'write_addr', 						wave: '2..............2..'  	,data: '0 1 2 3 4 5 6 7'},
    	{name: 'cycle_cnt', 						wave: '2..2...2...2...2..'  	,data: '0 1 2 3 0'},
     	 {name: 'temp_pixel', 						wave: '0..2...2...2...2..'  ,data: 'P0 P0P1 P0P1P2 0'},
  		{name:'pixel_mem[0]',   					wave: 'x..............2..'		,data: 'P0P1P2P3' },
		{name:'pixel_mem[1]',   					wave: 'x.................'		,data: '0 P4P5P6P7' },
  ]
],
  head: {
   text: 'PIXEL WRITING TO MEM',
   tick: 0,
 }
 ,"config" : {hscale : 2}
}