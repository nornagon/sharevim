net = require 'net'
{client} = require 'share'

onLine = (c, f) ->
	buf = ''
	c.on 'data', (d) ->
		buf = buf + d.toString()
		while (i = buf.indexOf('\n')) > 0
			line = buf.substr(0, i)
			buf = buf.substr(i+1)
			f line

mySeqNo = 1
nextBufID = 1
net.createServer (c) ->
	sharedoc = null

	myBufID = nextBufID++

	write = (args...) ->
		console.log "=> #{args[0].trimRight()}"
		c.write args...

	nb_cmd = (name, args...) ->
		args = if args.length > 0 then ' '+args.join(' ') else ''
		write "#{myBufID}:#{name}!#{mySeqNo++}#{args}\n"
	nb_func = (name, args...) ->
		args = if args.length > 0 then ' '+args.join(' ') else ''
		write "#{myBufID}:#{name}/#{mySeqNo++}#{args}\n"

	auth = (pw) ->
	reply = (seqno, cmd) ->
	event = (bufID, name, seqno, args) ->
		if name == 'startupDone'
			start()
		else if name == 'remove'
			[offset,bytes] = args.split(/\x20/).slice(1).map (a) -> parseInt a
			bytes += 1
			sharedoc.submitOp d:sharedoc.snapshot.substr(offset,bytes), p:offset
		else if name == 'insert'
			[offset,str...] = args.split(/\x20/).slice(1)
			sharedoc.submitOp i:JSON.parse(str.join(' '))+'\n', p:parseInt offset
	start = ->
		nb_cmd 'setFullName', JSON.stringify("hello #{myBufID}")
		nb_cmd 'initDone'
		nb_cmd 'startDocumentListen'
		share_go()

	handlers = []
	handle = (r,f) -> handlers.push([r,f])
	handle /^AUTH\s+(.*)\s*$/, auth
	handle /^(\d+)((?:\s+(?:\S+))*)$/, reply
	handle /^(\d+):(\w+)=(\d+)((?:\s+(?:\S+))*)$/, event

	onLine c, (line) ->
		console.log "<= #{line}"
		for [r,f] in handlers
			if (m = r.exec line)
				f.apply(undefined, m.slice(1))
				break

	share_go = ->
		client.open 'hello', 'text', {host: 'localhost', port:8000}, (doc, err) ->
			sharedoc = doc
			nb_func 'insert', '0', JSON.stringify(doc.snapshot)
			nb_cmd 'insertDone'
			doc.on 'remoteop', (op) ->
				console.log 'got op', op
				for component in op
					if component.d?
						nb_func 'remove', component.p, component.d.length
					if component.i?
						nb_func 'insert', component.p, JSON.stringify(component.i)

.listen 3424
