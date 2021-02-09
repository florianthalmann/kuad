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
	~buffers = ~buffers.add(Buffer.read(s, path.fullPath).normalize());
});
MIDIClient.init;
MIDIIn.connectAll;
~synths = Dictionary.new;
)

//MAKE ONE BASS SHITUGAIKI WITH FILTER!!!!!
//AND MAKE ONE FOR EWI....
//LIMITER

(
~maxAmp = 0.2;

SynthDef(\shitugaiki, {
	arg amp=~maxAmp, out=0, buf=0, pan=0.1, rate=0.4, noiz=0.0, freq=20, rhy=0.0, bps=1, rev=0.0;
	var sig;
	//make mono and vary rate
	rate = rate * BufRateScale.kr(buf)
	+ (noiz*(SinOsc.kr(freq+(SinOsc.kr(0.1))*9)));
	//+  (noiz*LFNoise1.kr(60));
	sig = Mix(PlayBuf.ar(2, buf, rate, loop:1));
	//amp with rythm component
	sig = sig * amp*((1-rhy)+(0.7*Saw.ar(bps)*rhy));
	sig = PanAz.ar(~numchannels, sig, pos:LFNoise1.kr(pan));
	Out.ar(out, FreeVerb.ar(sig, rev, 20));
}).add;

MIDIdef.cc(\cc, {
	arg func, ccNum;
	if (~synths.at(ccNum.asString).isNil, {
		~synths.put(ccNum.asString,
			Synth(\shitugaiki, [\buf, ~buffers[ccNum-21]])
			.onFree({ ~synths.removeAt(ccNum.asString)})); });
	~synths.at(ccNum.asString).set(\amp, ~maxAmp*func/128);
}).permanent_(true);
// MIDIdef.noteOn(\on, { |veloc, num, chan, src|
// 	~synths.values.do({arg s; s.set(\rate, num/60) });
// });
)

(
r = Routine({
	~synths.postln;
	~synths.values.do({arg s; s.set(\freq, 0.5)});
	wait(0.5);
	~synths.values.do({arg s; s.set(\freq, 5)});
	wait(0.5);
	~synths.values.do({arg s; s.set(\freq, 10)});
});
)

r.next

~synths.choose.free;

~synths.values.do({arg s; s.set(\rate, rrand(0.2,1))});

~synths.values.do({arg s; s.set(\freq, rrand(1,12))});
~synths.choose.set(\freq, rrand(1,6))

~synths.values.do({arg s; s.set(\rhy, rrand(0.0,1.0))});
~synths.choose.set(\rhy, 1)

~synths.choose.set(\noiz, 1)
~synths.choose.set(\pan, 0.11)

~synths.values.do({arg s; s.set(\rev, rrand(0.0,0.2))});
