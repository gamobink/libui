// 25 june 2016
#import "uipriv_darwin.h"

struct uiImage {
	NSImage *i;
	NSSize size;
	NSMutableArray *swizzled;
};

uiImage *uiNewImage(double width, double height)
{
	uiImage *i;

	i = uiprivNew(uiImage);
	i->size = NSMakeSize(width, height);
	i->i = [[NSImage alloc] initWithSize:i->size];
	i->swizzled = [NSMutableArray new];
	return i;
}

void uiFreeImage(uiImage *i)
{
	NSValue *v;

	[i->i release];
	// to be safe, do this after releasing the image
	for (v in i->swizzled)
		uiprivFree([v pointerValue]);
	[i->swizzled release];
	uiprivFree(i);
}

void uiImageAppend(uiImage *i, void *pixels, int pixelWidth, int pixelHeight, int byteStride)
{
	NSBitmapImageRep *repCalibrated, *repsRGB;
	uint8_t *swizzled, *bp, *sp;
	int x, y;
	unsigned char *pix[1];

	// OS X demands that R and B are in the opposite order from what we expect
	// we must swizzle :(
	// LONGTERM test on a big-endian system
	swizzled = (uint8_t *) uiprivAlloc((byteStride * pixelHeight) * sizeof (uint8_t), "uint8_t[]");
	bp = (uint8_t *) pixels;
	sp = swizzled;
	for (y = 0; y < pixelHeight; y++){
		for (x = 0; x < pixelWidth; x++) {
			sp[0] = bp[2];
			sp[1] = bp[1];
			sp[2] = bp[0];
			sp[3] = bp[3];
			sp += 4;
			bp += 4;
		}
		// jump over unused bytes at end of line
		bp += byteStride - pixelWidth * 4;
	}

	pix[0] = (unsigned char *) swizzled;
	repCalibrated = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:pix
		pixelsWide:pixelWidth
		pixelsHigh:pixelHeight
		bitsPerSample:8
		samplesPerPixel:4
		hasAlpha:YES
		isPlanar:NO
		colorSpaceName:NSCalibratedRGBColorSpace
		bitmapFormat:0
		bytesPerRow:byteStride
		bitsPerPixel:32];
	repsRGB = [repCalibrated bitmapImageRepByRetaggingWithColorSpace:[NSColorSpace sRGBColorSpace]];

	[i->i addRepresentation:repsRGB];
	[repsRGB setSize:i->size];
	// don't release repsRGB; it may be equivalent to repCalibrated
	// do release repCalibrated though; NSImage has a ref to either it or to repsRGB
	[repCalibrated release];

	// we need to keep swizzled alive for NSBitmapImageRep
	[i->swizzled addObject:[NSValue valueWithPointer:swizzled]];
}

NSImage *uiprivImageNSImage(uiImage *i)
{
	return i->i;
}
