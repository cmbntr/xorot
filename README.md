# xorot: ROT ∘ XOR ∘ ROT

```
            xorot ∘ xorot             =
(ROT ∘ XOR ∘ ROT) ∘ (ROT ∘ XOR ∘ ROT) =
 ROT ∘ XOR ∘ (ROT ∘ ROT) ∘ XOR ∘ ROT  =
 ROT ∘ XOR ∘     ID      ∘ XOR ∘ ROT  =
 ROT ∘ (XOR       ∘       XOR) ∘ ROT  = 
 ROT ∘           ID            ∘ ROT  =
(ROT              ∘              ROT) =
                 ID
```

## Example

### "Encode"
```
echo SECRET |
age -R <(curl -s https://github.com/cmbntr.keys) |
xorot > data.age.xorot
```

### "Decode"
```
xorot < data.age.xorot | age -d -i ~/.ssh/id_ed25519
```

### mapping table

```
dd if=/dev/zero bs=320 count=1 | xorot | xxd
```

```
00000000: aaab acad aeaf b0b1 b2b3 b4b5 b6b7 b8b9  ................
00000010: babb bcbd bebf c0c1 c2c3 c4c5 c6c7 c8c9  ................
00000020: cacb cccd cecf d0d1 d2d3 d4d5 d6d7 d8d9  ................
00000030: dadb dcdd dedf e0e1 e2e3 e4e5 e6e7 e8e9  ................
00000040: eaeb eced eeef f0f1 f2f3 f4f5 f6f7 f8f9  ................
00000050: fafb fcfd feff 0001 0203 0405 0607 0809  ................
00000060: 0a0b 0c0d 0e0f 1011 1213 1415 1617 1819  ................
00000070: 1a1b 1c1d 1e1f 2021 2223 2425 2627 2829  ...... !"#$%&'()
00000080: 2a2b 2c2d 2e2f 3536 3738 3930 3132 3334  *+,-./5678901234
00000090: 3a3b 3c3d 3e3f 404e 4f50 5152 5354 5556  :;<=>?@NOPQRSTUV
000000a0: 5758 595a 4142 4344 4546 4748 494a 4b4c  WXYZABCDEFGHIJKL
000000b0: 4d5b 5c5d 5e5f 606e 6f70 7172 7374 7576  M[\]^_`nopqrstuv
000000c0: 7778 797a 6162 6364 6566 6768 696a 6b6c  wxyzabcdefghijkl
000000d0: 6d7b 7c7d 7e7f 8081 8283 8485 8687 8889  m{|}~...........
000000e0: 8a8b 8c8d 8e8f 9091 9293 9495 9697 9899  ................
000000f0: 9a9b 9c9d 9e9f a0a1 a2a3 a4a5 a6a7 a8a9  ................
00000100: aaab acad aeaf b0b1 b2b3 b4b5 b6b7 b8b9  ................
00000110: babb bcbd bebf c0c1 c2c3 c4c5 c6c7 c8c9  ................
00000120: cacb cccd cecf d0d1 d2d3 d4d5 d6d7 d8d9  ................
00000130: dadb dcdd dedf e0e1 e2e3 e4e5 e6e7 e8e9  ................
```

## Background

```
First application of ROT ∘ XOR ∘ ROT:
  We start with some plaintext P.
  We apply ROT to P, and we get ROT(P).
  We then apply XOR to ROT(P) with some key K, and we get XOR(ROT(P), K).
  We apply ROT again to XOR(ROT(P), K) and get ROT(XOR(ROT(P), K)).

Second application of ROT ∘ XOR ∘ ROT:
  We start with the result from the first application ROT(XOR(ROT(P), K)).
  We apply ROT to it and get ROT(ROT(XOR(ROT(P), K))).
  Now we apply XOR to this with the same key K and get XOR(ROT(ROT(XOR(ROT(P), K))), K).
  Lastly, we apply ROT again and get ROT(XOR(ROT(ROT(XOR(ROT(P), K))), K)).
```
