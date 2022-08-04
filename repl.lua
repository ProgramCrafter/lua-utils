local prog = assert((...))

os.execute('rm ' .. prog .. ' && edit ' .. prog)
os.execute(prog)
