(
~numchannels = 4;
~out = 0;
~path = PathName(thisProcess.nowExecutingPath).parentPath++"audio/";
~maxamp = 0.2;

s = Server.local;
s.options.outDevice_( //ServerOptions.devices
	//"MacBook Pro Speakers"
	"MOTU UltraLite mk3 Hybrid"
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

	(21..28).do({arg i;
		~synths.put(i.asString,
			Synth(\shitugaiki, [\buf, ~buffers[i-21], \freq, exprand(50, 8000),
				\amp, 0, \out, ~out], ~mainGrp)
				.onFree({
					~synths.removeAt(i.asString);
					MIDIOut(1).noteOn(0, i-21+96, 0);
		}));
	});

	~rampSynths = {
		arg param, target, seconds;
		Routine {
			var currents, deltas;
			currents = Array.fill(~synths.size, 0);
			~synths.values.do({arg s,i; s.get(param, {arg v; currents[i] = v;})});
			s.sync;
			deltas = currents.collect({arg c; (target-c)/(seconds*10);});
			i = 0;
			while { i < (seconds*10) } {
				~synths.values.do({arg s, j; s.set(param, currents[j] + (i*deltas[j]);)});
				0.1.wait;
				i = i + 1;
			};
			"routine done".postln;
		}.play;
	};
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
		arg amp=1, out=0, buf=0, pan=0.1, rate=0.4, freq=1000, rq=0.01, bpfmix=0, detu=0.0, detf=0.2, noiz=0.0, ruff=20, rhy=0.0, bps=1, rev=0.0;
		var sig;
		//make mono and vary rate
		rate = rate * BufRateScale.ir(buf)
		+ (noiz*(SinOsc.kr(ruff+(SinOsc.kr(0.1))*9)))
		+ (detu*LFNoise1.kr(detf));
		sig = Mix(PlayBuf.ar(2, buf, rate, loop:1));
		//amp with rythm component
		sig = sig * amp*((1-rhy)+(0.7*Saw.ar(bps)*rhy));
		sig = XFade2.ar(sig, 5*BPF.ar(sig, freq, rq, 1/rq.sqrt), bpfmix*2-1);
		sig = FreeVerb.ar(sig, mix:rev, room:10);
		sig = PanAz.ar(~numchannels, sig, pos:LFNoise1.kr(pan));
		Out.ar(out, sig);
	}).add;

	MIDIdef.cc(\cc, {
		arg func, ccNum;
		//if (ccNum == 2, { ccNum = 30 });
		if ((21 <= ccNum).and(ccNum <= 28), {
			if (~synths.at(ccNum.asString).isNil, {
				~synths.put(ccNum.asString,
					Synth(\shitugaiki, [\buf, ~buffers[ccNum-21], \freq, exprand(50, 4000),
						\out, ~out], ~mainGrp)
					.onFree({
						~synths.removeAt(ccNum.asString);
						MIDIOut(1).noteOn(0, ccNum-21+96, 0);
				}));
				MIDIOut(1).noteOn(0, ccNum-21+96, 51);
			});
		});
		/*if (ccNum == 2,
			{ synth.set(\amp, func); });*/
		~synths.at(ccNum.asString).set(\amp, ~maxamp*func/128);
	}).permanent_(true);

	MIDIdef.noteOn(\on, { |veloc, num, chan, src|
		/*if ((96 <= num).and(num <= 103), {
			~synths.at((num-96+21).asString).free;
			MIDIOut(1).noteOn(0, num, 0);
		});*/
		[veloc, num].postln;
		if ((96 <= num).and(num <= 103), {
			~synths.at((num-96+21).asString).set(\freq, exprand(50, 2000));
			MIDIOut(1).noteOn(0, num, 51);
		});
		if ((112 <= num).and(num <= 119), {
			~synths.at((num-112+21).asString).set(\bps, rrand(1, 9));
			MIDIOut(1).noteOn(0, num, 51);
		});
	}).permanent_(true);

	s.sync;
	ServerTree.add(~makeNodes);
	ServerTree.add(~makeEvents);
	s.freeAll;
	s.sync;

	s.meter;
	"ready".postln;
});
)

MIDIClient.sources

//PLAN ROUTINE
//MAKE ONE BASS SHITUGAIKI WITH FILTER!!!!!
//AND MAKE ONE FOR EWI....

//MAKE ALL SYNTHS IN BEGINNING!!!!!!
//OTHER WAY TO GET RID OF FILTER SWEEP???????
//LIMITER: https://github.com/supercollider-quarks/BatLib/blob/master/StageLimiter.scv

~rampSynths.value(\amp, 0.0, 30);

~rampSynths.value(\rev, 0.0, 30);

~rampSynths.value(\freq, 400, 100);

~rampSynths.value(\bpfmix, 0, 30);
~rampSynths.value(\rhy, 0, 30);
~rampSynths.value(\noiz, 0, 30);
~rampSynths.value(\detu, 0, 30);
~rampSynths.value(\detf, 0, 30);

~rampSynths.value(\rq, 1/100, 30);

~rampSynths.value(\pan, 0.3, 30);

~synths.size

//~reverbSynth.set(\room, 10, \mix, 1);


~synths.put('a', Synth(\shitugaiki, [\buf, ~buffers[5], \detu, 0.01, \bpfmix, 1]));

~synths.choose.set(\bpfmix, 1);

~synths.choose.free;

~synths.choose.set(\rate, 0.8)

~synths.values.do({arg s; s.set(\detu, rrand(0, 3))});
~synths.values.do({arg s; s.set(\detf, rrand(0, 10))});
~synths.choose.set(\detu, 1)
~synths.choose.set(\detf, 1)

~synths.values.do({arg s; s.set(\bps, rrand(0.1,0.7))});//reich
~synths.values.do({arg s; s.set(\bps, rrand(2,11)*0.4)});
~synths.choose.set(\bps, 2.5)

~synths.values.do({arg s; s.set(\rhy, rrand(1,1))});
~synths.choose.set(\rhy, 0.3)

~synths.choose.set(\noiz, 1)
~synths.values.do({arg s; s.set(\noiz, rrand(0.01,0.1))});
~synths.choose.set(\pan, 1)

~synths.choose.set(\rev, 0)

~synths.choose.set(\rq, 1/1000)
~synths.choose.set(\bpfmix, 0);
~synths.choose.set(\freq, exprand(30, 80));
//~synths.choose.set(\freq, exprand(40, 1000));
~synths.values.do({arg s; s.set(\freq, exprand(40, 4000))});
~synths.values.do({arg s; s.set(\bpfmix, rrand(0.0,1.0))});

~synths.values.do({arg s; s.set(\rev, rrand(0.1,0.2))});
~synths.values.do({arg s; s.set(\rev, rrand(0,0))});


s.record(numChannels:4);
s.stopRecording;




