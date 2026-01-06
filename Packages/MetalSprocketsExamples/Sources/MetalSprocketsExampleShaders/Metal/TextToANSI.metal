#include "MetalSprocketsExampleShaders.h"

using namespace metal;

namespace TextToANSI {

    // Each cell is: "\x1b[38;2;RRR;GGG;BBBmX" = 20 bytes
    // Format: ESC [ 3 8 ; 2 ; R R R ; G G G ; B B B m X
    //         1   1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 = 20 bytes
    constant uint BYTES_PER_CELL = 20;

    // Helper to write a 3-digit number (000-255) to buffer
    inline void writeNumber(device char* buffer, uint offset, uchar value) {
        buffer[offset + 0] = '0' + (value / 100);
        buffer[offset + 1] = '0' + ((value / 10) % 10);
        buffer[offset + 2] = '0' + (value % 10);
    }

    kernel void colorToANSI(
        texture2d<float, access::read> inputTexture [[texture(0)]],
        device char* outputBuffer [[buffer(0)]],
        constant uchar* shadeChars [[buffer(1)]],
        constant uint& shadeCount [[buffer(2)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        uint width = inputTexture.get_width();
        uint height = inputTexture.get_height();

        if (gid.x >= width || gid.y >= height) {
            return;
        }

        // Read color from texture
        float4 color = inputTexture.read(gid);

        // Convert to 0-255 range
        uchar r = uchar(saturate(color.r) * 255.0);
        uchar g = uchar(saturate(color.g) * 255.0);
        uchar b = uchar(saturate(color.b) * 255.0);

        // Calculate luminance for character selection
        float luminance = 0.299 * color.r + 0.587 * color.g + 0.114 * color.b;
        uint shadeIndex = uint(saturate(luminance) * float(shadeCount - 1) + 0.5);
        char shadeChar = shadeChars[shadeIndex];

        // Calculate buffer offset for this pixel
        uint cellIndex = gid.y * width + gid.x;
        uint offset = cellIndex * BYTES_PER_CELL;

        // Write ANSI escape sequence: "\x1b[38;2;RRR;GGG;BBBmX"
        device char* cell = outputBuffer + offset;

        cell[0] = '\x1b';  // ESC
        cell[1] = '[';
        cell[2] = '3';
        cell[3] = '8';
        cell[4] = ';';
        cell[5] = '2';
        cell[6] = ';';
        writeNumber(cell, 7, r);   // RRR at positions 7,8,9
        cell[10] = ';';
        writeNumber(cell, 11, g);  // GGG at positions 11,12,13
        cell[14] = ';';
        writeNumber(cell, 15, b);  // BBB at positions 15,16,17
        cell[18] = 'm';
        cell[19] = shadeChar;
    }

} // namespace TextToANSI
