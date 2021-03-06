#ifndef __poly_convert_h__
#define __poly_convert_h__

#include "../gfxdevice.h"
#include "poly.h"

typedef struct _polywriter
{
    void(*moveto)(struct _polywriter*, int32_t x, int32_t y);
    void(*lineto)(struct _polywriter*, int32_t x, int32_t y);
    void(*setgridsize)(struct _polywriter*, double g);
    void*(*finish)(struct _polywriter*);
    void*internal;
} polywriter_t;

void gfxpolywriter_init(polywriter_t*w);
gfxpoly_t* gfxpoly_from_gfxline(gfxline_t*line, double gridsize);
gfxpoly_t* gfxpoly_from_file(const char*filename, double gridsize);
void gfxpoly_destroy(gfxpoly_t*poly);

#endif //__poly_convert_h__
