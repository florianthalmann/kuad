(
~numchannels = 2;
~out = 0;
~path = PathName(thisProcess.nowExecutingPath).parentPath++"audio/";
~maxamp = 0.2;

s = Server.local;
s.options.outDevice_( //ServerOptions.devices
	"MacBook Pro Speakers"
	//"External Headphones"
);
s.options.numOutputBusChannels_(~numchannels);
s.options.sampleRate_(44100);
s.options.memSize_(2.pow(20));

~makeBuffers = {
	~buffers = Array.new;
	PathName(~path).entries.do({
		arg path;
		~buffers = ~buffers.add(Buffer.read(s, path.fullPath).normalize());
	});
};

~makeBusses = {
	~bus = Dictionary.new;
	~bus.put(\reverb, Bus.audio(s, ~numchannels));
};

~makeNodes = {
	~mainGrp = Group.new;
	~reverbGrp = Group.after(~mainGrp);
	~reverbSynth = Synth(\reverbSynth, [\in, ~bus[\reverb]], ~reverbGrp);

	~synths = Dictionary.new;
};

~makeEvents = {
	MIDIClient.init;
	MIDIIn.connectAll;
	MIDIOut(1).noteOn(0, 12, 127);
	e = Dictionary.new;
};

~cleanup = {
	s.newBusAllocators;
	ServerBoot.removeAll;
	ServerTree.removeAll;
	ServerQuit.removeAll;
};

ServerBoot.add(~makeBuffers);
ServerBoot.add(~makeBusses);
ServerQuit.add(~cleanup);

s.waitForBoot({
	s.sync;

	SynthDef(\reverbSynth, {
		arg in, mix=0, room=20;
		Out.ar(~out, FreeVerb.ar(In.ar(in), mix:mix, room:room));
	}).add;

	SynthDef(\shitugaiki, {
		arg amp=1, out=0, buf=0, pan=0.1, rate=0.4, freq=1000, rq=0.01, bpfmix=0, detu=0.0, noiz=0.0, ruff=20, rhy=0.0, bps=1, rev=0.0;
		var sig;
		//make mono and vary rate
		rate = rate * BufRateScale.ir(buf)
		+ (noiz*(SinOsc.kr(ruff+(SinOsc.kr(0.1))*9)))
		+ (detu*LFNoise1.kr(0.2));
		sig = Mix(PlayBuf.ar(2, buf, rate, Dust.kr(0), TIRand.kr(10000, 200000), loop:1));
		//amp with rythm component
		sig = XFade2.ar(sig, BPF.ar(sig, freq, rq, 1/rq.sqrt), bpfmix*2-1);
		sig = sig * amp*((1-rhy)+(0.7*Saw.ar(bps)*rhy));
		sig = PanAz.ar(~numchannels, sig, pos:LFNoise1.kr(pan));
		Out.ar(out, sig);
	}).add;

	MIDIdef.cc(\cc, {
		arg func, ccNum;
		if (~synths.at(ccNum.asString).isNil, {
			~synths.put(ccNum.asString,
				Synth(\shitugaiki, [\buf, ~buffers[ccNum-21],
					\out, ~bus[\reverb]], ~mainGrp)
				.onFree({ ~synths.removeAt(ccNum.asString)}));
			MIDIOut(1).noteOn(0, ccNum-21+96, 51);
		});
		~synths.at(ccNum.asString).set(\amp, ~maxamp*func/128);
	}).permanent_(true);

	MIDIdef.noteOn(\on, { |veloc, num, chan, src|
		if ((96 <= num).and(num <= 103), {
			~synths.at((num-96+21).asString).free;
			MIDIOut(1).noteOn(0, num, 0);
		});
	});

	s.sync;
	ServerTree.add(~makeNodes);
	ServerTree.add(~makeEvents);
	s.freeAll;
	s.sync;
	"ready".postln;
});
)

MIDIClient.destinations
(
m = MIDIOut(1);
m.noteOn(0, 12, 127);
m.noteOn(0, 96, 51);
)

//PLAN ROUTINE
//MAKE ONE BASS SHITUGAIKI WITH FILTER!!!!!
//AND MAKE ONE FOR EWI....
//LIMITER: https://github.com/supercollider-quarks/BatLib/blob/master/StageLimiter.sc


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

~reverbSynth.set(\room, 0, \mix, 1);

r.next

~synths.put('a', Synth(\shitugaiki, [\buf, ~buffers[5], \detu, 0.01, \bpfmix, 1]))

~synths.choose.free;

~synths.values.do({arg s; s.set(\rate, rrand(0.2,1))});

~synths.values.do({arg s; s.set(\bps, rrand(1,12))});
~synths.choose.set(\bps, rrand(1,6))

~synths.values.do({arg s; s.set(\rhy, rrand(0.0,1.0))});
~synths.choose.set(\rhy, 0.9)

~synths.choose.set(\noiz, 1)
~synths.choose.set(\pan, 0.11)

~synths.choose.set(\rq, 1/100)
~synths.choose.set(\freq, 300)

~synths.values.do({arg s; s.set(\rev, rrand(0.0,0.2))});
