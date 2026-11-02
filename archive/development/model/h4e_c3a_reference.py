"""Independent list-based integer statistics; no RTL state-machine model."""
def expected(pattern):
    pixels=[]
    for y in range(16):
        for x in range(16):
            if pattern<4: p=[(220,30,10),(20,200,40),(15,25,210),(255,255,255)][pattern]
            elif pattern==4: p=(x*16+y,255-x*16-y,(x*16+y)//2)
            else: p=(20,50,230) if x<8 else (201,100,3)
            pixels.append(p)
    result={'count':len(pixels)}
    for i,c in enumerate('rgb'):
        values=[p[i] for p in pixels]
        result.update({ 's'+c:sum(values),'l'+c:min(values),'h'+c:max(values),'m'+c:sum(values)//len(values)})
    return result
