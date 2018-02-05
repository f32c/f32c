pipeline_name = 'ieee_adder'
file_input = 'ieee.v'
file_output = 'ieee_adder.v'
clock_name = 'clock_in'
inputs = [
	('bit','add_sub_bit'), 
	('number','inputA'), 
	('number','inputB'), 
	('bit', clock_name)
]
outputs = [('number','outputC')]
v_includes = '`include "defines.v"\n'

widths = {
	'bit' : '',
	'number':'`WIDTH_NUMBER',
	'signif':'`WIDTH_SIGNIF',
	'expo'  :'`WIDTH_EXPO',
	's_part':'`WIDTH_SIGNIF_PART',
	'[4:0]':'[4:0]',
}

stages = [
	{ #Stage
		'components':[
			{'name':'prepare_input',
				'suffix':'A',
				'override_input':{'number':'inputA','add_sub_bit':"1'b0",}},
			{'name':'prepare_input',
				'suffix':'B',
				'override_input':{'number':'inputB','add_sub_bit':'add_sub_bit',}},
			{'name':'compare',},
		],
	},
	{ #Stage
		'components':[
			{'name':'shift_signif',},
			{'name':'swap_signif',},
			{'name':'bigger_exp'},
			{'name':'opadd'},
			{'name':'opsub'},
		],
	},
	{ #Stage
		'components':[
			{'name':'normalize_sub',},
		],
	},
	{ #Stage
		'components':[
			{'name':'round',
				'suffix':'_add',
				'override_input':{'number':'out_signif_add'}},
			{'name':'round',
				'suffix':'_sub',
				'override_input':{'number':'out_signif_sub'}},
			{'name':'final',},
		],
	},
]
