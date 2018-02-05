from __future__ import print_function
import re
import sys

def widthFind(val, widths):
	for name in widths:
		if widths[name] == val:
			return name
	print("Could not find a type: " + val)
	sys.exit(-1)

def readNoComments(f):
	file = ''
	comment = False
	for line in f:
		if comment:
			pos = line.find('*/')
			if pos < 0:
				continue
			else:
				line = line[pos+2:]
				comment = False
		pos = line.find('/*')
		if pos >= 0:
			line = line[0:pos]
			comment = True
		pos = line.find('//')
		if pos >= 0:
			line = line[0:pos]
		line = line.strip()
		if len(line):
			file += line + " "
	return file

def readModules(file, module_name, widths):
	parts = file.split("module "+module_name+"_")[1:]

	modules = {}

	for module in parts:
		end = module.find('endmodule')
		if end < 0:
			raise Exception('endmodule not found')
		module = module[:end]
		name = re.match('[A-Za-z0-9_]+',module).group(0)
		print('Found a module: "'+name+'"')
		posopen = module.find('(')
		posclose = module.find(')',posopen)
		minouts = []
		statements = module[posclose+1:].split(';')
		for inout in module[posopen+1:posclose].split(','):
			inout = inout.strip()
			p = inout.rsplit(' ', 1)
			if len(p) == 1:
				minouts.append(p[0])
			else:
				minouts.append(p[1])
				statements.append(inout)
		
		minputs = []
		moutputs = []
		for line in statements:
			line = line.strip()
			if line.startswith('input') or line.startswith('output'):
				pos = line.find(' ')
				line2 = line[pos+1:].strip()
				pos = line2.rfind(' ')
				if pos < 0:
					typename = 'bit'
					ioname = line2.strip()
				else:
					type = line2[:pos].strip()
					ioname = line2[pos:].strip()
					typename = widthFind(type, widths)
				if ioname.startswith('__'):
					continue
				if line.startswith('input'):
					minputs.append( (typename, ioname))
					#print('  input',ioname)
				else:
					moutputs.append( (typename, ioname))
					#print('  output',ioname)
				if ioname not in minouts:
					print("------------------------------------------")
					print("Warning:", ioname, "is missing in I/O list.")
					print("------------------------------------------")
		modules[name] = {
			'name':name,
			'inputs':minputs,
			'outputs':moutputs,
		}
	return modules
