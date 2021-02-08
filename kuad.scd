(
~numchannels = 2;
s.options.numOutputBusChannels = ~numchannels;
s.boot;
s.meter;
)

(
~buffers = Array.new;
PathName(PathName(thisProcess.nowExecutingPath).parentPath ++ "audio").entries.do({
	arg path;
	~buffers = ~buffers.add(Buffer.read(s, path.fullPath));
});
MIDIClient.init;
MIDIIn.connectAll;
~synths = Dictionary.new;
)

//NORMALIZE BUFFERS!!!!!!

(
SynthDef(\shitugaiki, {
	arg amp=0.2, pos=0, out=0, buf=0, fade=4, rate=0.4, loop=1, freq=1, amnt=0.01, rev=0.0;
	var sig;
	sig = PlayBuf.ar(2, buf, rate * BufRateScale.kr(buf), loop:loop);
	//+ (LFNoise1.kr(10)*3) -1
	//+ (SinOsc.ar(10)*1)
	//(SinOsc.kr(20+SinOsc.kr(0.1)*9))
	//(SinOsc.kr(20+(SinOsc.kr(0.1))*9))
	//(SinOsc.kr(10+(SinOsc.kr(0.1))*9))
	//(LFNoise1.kr(freq)*amnt) -1
	sig = PanAz.ar(~numchannels, Mix(sig), LFNoise1.ar(0.1), amp+(Saw.ar(freq)*amnt));// * Line.ar(0, 1, fade));
	Out.ar(out, FreeVerb.ar(sig, rev, 20));
}).add;

MIDIdef.cc(\cc, {
	arg func, ccNum;
	//[func, ccNum].postln;
	if (~synths.at(ccNum.asString).isNil, {
		~synths.put(ccNum.asString, Synth(\shitugaiki, [\buf, ~buffers.choose])); });
	~synths.at(ccNum.asString).set(\amp, func/128);
});
// MIDIdef.noteOn(\on, { |veloc, num, chan, src|
// 	~synths.values.do({arg s; s.set(\rate, num/60) });
// });
)

(
r = Routine({
	~synths.values.do({arg s; s.set(\freq, 0.5)});
	wait(0.5);
	~synths.values.do({arg s; s.set(\freq, 5)});
	wait(0.5);
	~synths.values.do({arg s; s.set(\freq, 10)});
});
)

b = ~buffers.choose
b.play
b.free

~synths.values.do({arg s; s.set(\rate, 1)});

~synths.values.do({arg s; s.set(\freq, rrand(1,7))});
~synths.choose.set(\freq, 1.8)

~synths.values.do({arg s; s.set(\amnt, 0.01)});
~synths.choose.set(\amnt, 1)

~synths.values.do({arg s; s.set(\rev, 0.0)});

r.next

{ c = ~synths.choose; c.free; ~synths.removeAt(c); }.value;

~synths

{ ~synths.values.do({arg s; s.free}); ~synths = Dictionary.new; }.value;
