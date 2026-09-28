import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/voice/audio.dart';

void main() {
  test(
    'PCM16 little-endian samples normalize correctly across split chunks',
    () {
      final pcm = Pcm16Accumulator(maximumSamples: 4);
      pcm.add(Uint8List.fromList([0x00, 0x80, 0xff]));
      pcm.add(Uint8List.fromList([0x7f, 0x00, 0x00, 0x00, 0xc0]));

      expect(pcm.takeSamples(), [
        -1.0,
        closeTo(32767 / 32768, 1e-8),
        0.0,
        -0.5,
      ]);
    },
  );

  test('one chunk holds 30 seconds and says where the next one starts', () {
    final pcm = Pcm16Accumulator();
    final bytes = Uint8List((voiceChunkSamples + 100) * 2);
    final taken = pcm.add(bytes);

    expect(taken, voiceChunkSamples * 2);
    expect(pcm.length, voiceChunkSamples);
    expect(pcm.duration, voiceChunkDuration);
    expect(pcm.isFull, isTrue);
    expect(pcm.add(bytes, taken), 0);
    expect(pcm.takeSamples(), hasLength(voiceChunkSamples));
    // The rest of the same buffer starts the next chunk.
    expect(pcm.add(bytes, taken), 200);
    expect(pcm.length, 100);
  });

  test('an odd byte at a chunk edge carries into the next chunk', () {
    final pcm = Pcm16Accumulator(maximumSamples: 2);
    // Two samples fill the chunk; the third sample's low byte is left over.
    final bytes = Uint8List.fromList([0, 0, 0, 0x40, 0x00]);
    final taken = pcm.add(bytes);
    expect(taken, 4);
    expect(pcm.takeSamples(), [0.0, 0.5]);
    expect(pcm.add(bytes, taken), 1);
    pcm.add(Uint8List.fromList([0xc0]));
    expect(pcm.takeSamples(), [-0.5]);
  });
}
