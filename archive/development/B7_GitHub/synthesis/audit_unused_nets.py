"""Accept TD undriven-bit diagnostics only when exported RTL has no users of those bits."""
import re


def audit(log, verilog):
    errors=[s for s in log.splitlines() if re.search(r'\bERROR:',s)]
    pattern=r'SYN-8115 ERROR: Netlist check -- net "([^"\[]+)\[(\d+)\]".* is undriven'
    reports=[re.search(pattern,s) for s in errors]
    if not reports or any(m is None for m in reports) or 'messages will be suppressed' in log:
        raise RuntimeError('Undriven audit is missing, truncated, or contains other errors')
    modules=re.findall(r'(?ms)^module\s+(\S+).*?endmodule',verilog)
    bodies=re.findall(r'(?ms)^module\s+\S+.*?endmodule',verilog)
    reviewed=[]
    for match in reports:
        name,bit=match.group(1),int(match.group(2))
        declaration=re.compile(r'(?m)^\s*wire\s+(?:\[[^\]]+\]\s+)?'+re.escape(name)+r'\s*;[^\n]*$')
        found=False
        for module,body in zip(modules,bodies):
            if not declaration.search(body): continue
            found=True
            clean=declaration.sub('',body)
            clean=re.sub(r'//[^\n]*','',clean)
            for use in re.finditer(r'(?<![\w$])'+re.escape(name)+r'(?![\w$])\s*(\[[^\]]+\])?',clean):
                selection=use.group(1)
                if selection is None:
                    raise RuntimeError(f'Undriven {name}[{bit}] used as full vector in {module}')
                numbers=re.fullmatch(r'\[(\d+)(?::(\d+))?\]',selection)
                if numbers is None:
                    raise RuntimeError(f'Cannot bound a dynamic use of {name}[{bit}]')
                high=int(numbers.group(1)); low=int(numbers.group(2) or high)
                if min(high,low)<=bit<=max(high,low):
                    raise RuntimeError(f'Undriven {name}[{bit}] is referenced in {module}')
        if not found: raise RuntimeError(f'Cannot find declaration for {name}[{bit}]')
        reviewed.append(f'{name}[{bit}]')
    return {'passed':True,'method':'Every diagnosed bit has zero references after declarations are removed.',
            'diagnostic_count':len(reviewed),'unused_bits':reviewed}
