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

net.createServer (c) ->
	sharedoc = null

	mySeqNo = 1

	write = (args...) ->
		console.log "=> #{args[0].trimRight()}"
		c.write args...

	nb_cmd = (bufID, name, args...) ->
		args = if args.length > 0 then ' '+args.join(' ') else ''
		write "#{bufID}:#{name}!#{mySeqNo++}#{args}\n"
	nb_func = (bufID, name, args...) ->
		args = if args.length > 0 then ' '+args.join(' ') else ''
		write "#{bufID}:#{name}/#{mySeqNo++}#{args}\n"

	auth = (pw) ->
	reply = (seqno, cmd) ->
	event = (bufID, name, seqno, args) ->
		if name == 'startupDone'
			start()
		else if name == 'remove'
			[offset,bytes] = args.split(/\x20/).slice(1).map (a) -> parseInt a
			sharedoc.submitOp d:sharedoc.snapshot.substr(offset,bytes), p:offset
		else if name == 'insert'
			[offset,str...] = args.split(/\x20/).slice(1)
			sharedoc.submitOp i:JSON.parse(str.join ' '), p:parseInt offset
	start = ->
		nb_cmd 1, 'setFullName', '"hello"'
		nb_cmd 1, 'initDone'
		nb_cmd 1, 'startDocumentListen'

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

	client.open 'hello', 'text', {host: 'localhost', port:8000}, (doc, err) ->
		sharedoc = doc
		nb_func 1, 'insert', '0', JSON.stringify(doc.snapshot)
		doc.on 'remoteop', (op) ->
			for component in op
				if component.d?
					nb_func 1, 'remove', component.p, component.d.length
				if component.i?
					nb_func 1, 'insert', component.p, JSON.stringify(component.i)

.listen 3424
