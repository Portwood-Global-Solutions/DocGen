/**
 * DocGenPngEncoder
 *
 * Pure-Apex PNG (8-bit indexed color) encoder, used by the server-side
 * chart rasterizer (#117) to embed real PNGs in DOCX without a browser
 * canvas. Apex has no native DEFLATE API, so the IDAT compressed stream
 * is produced via the Compression.ZipWriter trick:
 *
 *   1. Stuff the filtered pixel data into a single-entry ZIP (which
 *      ZipWriter compresses with DEFLATE by default — verified against
 *      portwood-staging).
 *   2. Parse the resulting ZIP's central directory to locate the local
 *      file header → skip header bytes → grab the raw DEFLATE payload.
 *   3. Wrap the DEFLATE bytes in a zlib header (78 9C) + adler-32 trailer.
 *   4. Emit as a PNG IDAT chunk.
 *
 * Public API:
 *   Blob png = DocGenPngEncoder.emitIndexed8(
 *       width, height, paletteRGB, indexedPixels
 *   );
 *
 *   paletteRGB:    List<Integer> of length 3N, flattened R0,G0,B0,R1,G1,B1,...
 *                  (up to 256 colors; first 16 are typically enough for charts)
 *   indexedPixels: List<Integer> of length width*height, each entry a palette index
 *
 * Heap budget: for a 500x280 chart, the filtered pixel data is ~140 KB
 * uncompressed; DEFLATE compresses our flat-color charts to ~5-30 KB. Peak
 * heap during encoding is ~3x the uncompressed size (raw List<Integer> +
 * hex string + intermediate Blobs), well under the 6 MB sync limit.
 */
public class DocGenPngEncoder {
    // PNG file signature (8 bytes)
    private static final List<Integer> PNG_SIG = new List<Integer>{ 137, 80, 78, 71, 13, 10, 26, 10 };

    // PNG CRC-32 table (poly 0xEDB88320). Built once on first access.
    private static List<Integer> crcTable;

    /**
     * Top-level API. Encodes an 8-bit indexed-color PNG.
     */
    public static Blob emitIndexed8(Integer width, Integer height, List<Integer> paletteRGB, List<Integer> pixels) {
        if (width <= 0 || height <= 0) {
            throw new DocGenException('PNG width/height must be positive');
        }
        if (pixels == null || pixels.size() != width * height) {
            throw new DocGenException('PNG pixel buffer size must equal width*height');
        }
        if (paletteRGB == null || paletteRGB.isEmpty() || Math.mod(paletteRGB.size(), 3) != 0) {
            throw new DocGenException('PNG palette must be a non-empty multiple of 3 RGB bytes');
        }
        Integer paletteEntries = paletteRGB.size() / 3;
        if (paletteEntries > 256) {
            throw new DocGenException('PNG indexed palette exceeds 256 entries');
        }

        // ── Build filtered pixel data: 1 filter byte (0 = None) + width pixel bytes per row.
        List<Integer> filtered = new List<Integer>();
        for (Integer y = 0; y < height; y++) {
            filtered.add(0);
            Integer rowStart = y * width;
            for (Integer x = 0; x < width; x++) {
                filtered.add(pixels[rowStart + x]);
            }
        }

        // ── Compress filtered data via DEFLATE (extracted from a single-entry ZIP).
        List<Integer> deflateBytes = deflateViaZipWriter(filtered);

        // ── Wrap DEFLATE in a zlib stream: 78 9C header + DEFLATE + adler-32 of UNCOMPRESSED data.
        Integer adler = adler32(filtered);
        List<Integer> zlibStream = new List<Integer>{ 120, 156 }; // 0x78 0x9C
        zlibStream.addAll(deflateBytes);
        writeBE32(zlibStream, adler);

        // ── Build PNG chunks.
        List<Integer> out = new List<Integer>();
        out.addAll(PNG_SIG);

        // IHDR (13 bytes): width(4) + height(4) + bit depth(1) + color type(1) + comp(1) + filter(1) + interlace(1)
        List<Integer> ihdr = new List<Integer>();
        writeBE32(ihdr, width);
        writeBE32(ihdr, height);
        ihdr.add(8); // bit depth
        ihdr.add(3); // color type: indexed-color
        ihdr.add(0); // compression: 0 (DEFLATE)
        ihdr.add(0); // filter: 0 (adaptive — but we used None throughout)
        ihdr.add(0); // interlace: none
        appendChunk(out, 'IHDR', ihdr);

        // PLTE: palette as flat RGB
        appendChunk(out, 'PLTE', paletteRGB);

        // IDAT: zlib-wrapped DEFLATE of filtered pixel data
        appendChunk(out, 'IDAT', zlibStream);

        // IEND: empty payload
        appendChunk(out, 'IEND', new List<Integer>());

        return bytesToBlob(out);
    }

    // =====================================================================
    // PNG chunk + checksum helpers
    // =====================================================================

    /**
     * Appends a length-prefixed PNG chunk with its CRC-32 to `out`.
     * Chunk shape: length(4 BE) | type(4 ASCII) | data(N) | crc32(4 BE)
     */
    private static void appendChunk(List<Integer> out, String type4, List<Integer> data) {
        writeBE32(out, data.size());
        List<Integer> typeBytes = stringToBytes(type4);
        out.addAll(typeBytes);
        out.addAll(data);
        // CRC over type + data
        List<Integer> crcInput = new List<Integer>(typeBytes);
        crcInput.addAll(data);
        writeBE32(out, crc32(crcInput));
    }

    /**
     * Standard PNG CRC-32 (poly 0xEDB88320, reflected). Iterates input bytes,
     * updates a 32-bit register held as an Apex Integer (signed 32-bit — bit
     * operations are equivalent to unsigned for our purposes; final adjusted
     * by XORing -1 which equals 0xFFFFFFFF in two's complement).
     */
    private static Integer crc32(List<Integer> data) {
        if (crcTable == null) {
            crcTable = buildCrcTable();
        }
        Integer c = -1; // 0xFFFFFFFF
        for (Integer i = 0; i < data.size(); i++) {
            Integer idx = (c ^ data[i]) & 255;
            c = (c >>> 8) ^ crcTable[idx];
        }
        return c ^ -1;
    }

    private static List<Integer> buildCrcTable() {
        List<Integer> t = new List<Integer>();
        for (Integer n = 0; n < 256; n++) {
            Integer c = n;
            for (Integer k = 0; k < 8; k++) {
                if ((c & 1) != 0) {
                    c = -306674912 ^ (c >>> 1); // -306674912 = 0xEDB88320 as signed int
                } else {
                    c = c >>> 1;
                }
            }
            t.add(c);
        }
        return t;
    }

    /**
     * Adler-32 checksum used in the zlib stream trailer (NOT the DEFLATE
     * payload). Operates on the UNCOMPRESSED data.
     */
    private static Integer adler32(List<Integer> data) {
        Integer a = 1;
        Integer b = 0;
        Integer MOD = 65521;
        for (Integer i = 0; i < data.size(); i++) {
            a = Math.mod(a + data[i], MOD);
            b = Math.mod(b + a, MOD);
        }
        return (b * 65536) + a;
    }

    // =====================================================================
    // DEFLATE via ZipWriter trick
    // =====================================================================

    /**
     * Compress `raw` bytes through Compression.ZipWriter (which defaults to
     * DEFLATE method 8 — confirmed empirically against portwood-staging),
     * then surgically extract the DEFLATE payload by parsing the ZIP's
     * central directory.
     *
     * ZIP structure produced by ZipWriter (single entry):
     *   [Local file header][filename][extra][DEFLATE data]
     *   [(optional) data descriptor]
     *   [Central directory entry][filename][extra][(comment)]
     *   [EOCD]
     *
     * Salesforce sets the data-descriptor flag (bit 3) so compressed/
     * uncompressed sizes in the local header are 0 — we read the real
     * compressed size from the central directory instead.
     */
    private static List<Integer> deflateViaZipWriter(List<Integer> raw) {
        Blob rawBlob = bytesToBlob(raw);
        Compression.ZipWriter zw = new Compression.ZipWriter();
        zw.addEntry('d', rawBlob); // entry name kept to 1 char to minimize header size
        Blob zipBlob = zw.getArchive();
        String hex = EncodingUtil.convertToHex(zipBlob).toLowerCase();
        return parseDeflateFromZipHex(hex);
    }

    /**
     * Walks the ZIP hex from the END to find the EOCD signature 504b0506,
     * reads the central directory offset, parses the CD entry to get the
     * compressed size and local header offset, then extracts that many
     * compressed bytes from the local file's data region.
     */
    @TestVisible
    private static List<Integer> parseDeflateFromZipHex(String hex) {
        // EOCD: walk backwards looking for "504b0506". Minimum EOCD is 22
        // bytes = 44 hex chars, so it's somewhere in the last (44 + commentLen)
        // chars. ZipWriter typically uses no comment, so EOCD is at hex.length-44.
        Integer eocdHex = -1;
        for (Integer i = hex.length() - 44; i >= 0; i -= 2) {
            if (hex.substring(i, i + 8) == '504b0506') {
                eocdHex = i;
                break;
            }
        }
        if (eocdHex < 0) {
            throw new DocGenException('ZIP EOCD not found — ZipWriter output unexpected');
        }
        // CD offset at byte 16 from EOCD start = hex offset eocdHex+32
        Integer cdOffsetBytes = readU32LE(hex, eocdHex + 32);
        Integer cdHex = cdOffsetBytes * 2;
        // Central directory entry: signature 504b0102 (verify)
        if (hex.substring(cdHex, cdHex + 8) != '504b0102') {
            throw new DocGenException('ZIP central directory entry signature missing');
        }
        // CD entry fields (offsets from CD entry start):
        //   20: compressed size (4 LE)
        //   42: local header offset (4 LE)
        Integer compSize = readU32LE(hex, cdHex + 40);
        Integer localHeaderOffsetBytes = readU32LE(hex, cdHex + 84);
        Integer localHex = localHeaderOffsetBytes * 2;
        if (hex.substring(localHex, localHex + 8) != '504b0304') {
            throw new DocGenException('ZIP local file header signature missing');
        }
        // Local header: signature(4) ver(2) flags(2) method(2) time(2) date(2)
        //               crc32(4) compSize(4) uncompSize(4) fnLen(2) extraLen(2)
        // = 30 bytes header → hex offset 30*2=60
        // fnLen at byte 26 = hex 52; extraLen at byte 28 = hex 56
        Integer fnLen = readU16LE(hex, localHex + 52);
        Integer extraLen = readU16LE(hex, localHex + 56);
        Integer deflateStartHex = localHex + 60 + (fnLen * 2) + (extraLen * 2);
        Integer deflateEndHex = deflateStartHex + (compSize * 2);
        String deflateHex = hex.substring(deflateStartHex, deflateEndHex);
        Blob deflateBlob = EncodingUtil.convertFromHex(deflateHex);
        return blobToBytes(deflateBlob);
    }

    // =====================================================================
    // Byte / int helpers
    // =====================================================================

    /** Big-endian uint32 → append 4 bytes. */
    private static void writeBE32(List<Integer> bytes, Integer value) {
        bytes.add((value >>> 24) & 255);
        bytes.add((value >>> 16) & 255);
        bytes.add((value >>> 8) & 255);
        bytes.add(value & 255);
    }

    /** Little-endian uint32 read at hex offset (hex chars = bytes * 2). */
    private static Integer readU32LE(String hex, Integer hexOffset) {
        Integer b0 = hex2byte(hex, hexOffset);
        Integer b1 = hex2byte(hex, hexOffset + 2);
        Integer b2 = hex2byte(hex, hexOffset + 4);
        Integer b3 = hex2byte(hex, hexOffset + 6);
        return b0 + (b1 * 256) + (b2 * 65536) + (b3 * 16777216);
    }

    /** Little-endian uint16 read at hex offset. */
    private static Integer readU16LE(String hex, Integer hexOffset) {
        Integer b0 = hex2byte(hex, hexOffset);
        Integer b1 = hex2byte(hex, hexOffset + 2);
        return b0 + (b1 * 256);
    }

    /** Read a single byte (2 hex chars) at offset. */
    private static Integer hex2byte(String hex, Integer hexOffset) {
        String two = hex.substring(hexOffset, hexOffset + 2);
        Integer hi = '0123456789abcdef'.indexOf(two.substring(0, 1));
        Integer lo = '0123456789abcdef'.indexOf(two.substring(1, 2));
        return hi * 16 + lo;
    }

    /** ASCII string → byte list. PNG chunk types are pure ASCII. */
    private static List<Integer> stringToBytes(String s) {
        List<Integer> out = new List<Integer>();
        for (Integer i = 0; i < s.length(); i++) {
            // Apex String.charAt returns the codepoint as Integer (UTF-16 code unit).
            // PNG chunk types are uppercase ASCII so single byte is correct.
            out.add(s.charAt(i));
        }
        return out;
    }

    /** Convert a List<Integer> of bytes to a Blob via hex round-trip. */
    @TestVisible
    private static Blob bytesToBlob(List<Integer> bytes) {
        String hexChars = '0123456789abcdef';
        // Build hex via a list-join — much faster than +=  for large outputs.
        List<String> parts = new List<String>();
        for (Integer i = 0; i < bytes.size(); i++) {
            Integer b = bytes[i] & 255;
            parts.add(hexChars.substring(b / 16, b / 16 + 1));
            parts.add(hexChars.substring(Math.mod(b, 16), Math.mod(b, 16) + 1));
        }
        return EncodingUtil.convertFromHex(String.join(parts, ''));
    }

    /** Convert a Blob to a List<Integer> of bytes (via hex). */
    private static List<Integer> blobToBytes(Blob b) {
        String hex = EncodingUtil.convertToHex(b).toLowerCase();
        List<Integer> out = new List<Integer>();
        for (Integer i = 0; i < hex.length(); i += 2) {
            out.add(hex2byte(hex, i));
        }
        return out;
    }
}
