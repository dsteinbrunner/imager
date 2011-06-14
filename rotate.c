/*
=head1 NAME

  rotate.c - implements image rotations

=head1 SYNOPSIS

  i_img *i_rotate90(i_img *src, int degrees)

=head1 DESCRIPTION

Implements basic 90 degree rotations of an image.

Other rotations will be added as tuits become available.

=cut
*/

#include "imager.h"
#include "imageri.h"
#include <math.h> /* for floor() */

i_img *i_rotate90(i_img *src, int degrees) {
  i_img *targ;
  i_img_dim x, y;

  i_clear_error();

  if (degrees == 180) {
    /* essentially the same as flipxy(..., 2) except that it's not
       done in place */
    targ = i_sametype(src, src->xsize, src->ysize);
    if (src->type == i_direct_type) {
      if (src->bits == i_8_bits) {
        i_color *vals = mymalloc(src->xsize * sizeof(i_color));
        for (y = 0; y < src->ysize; ++y) {
          i_color tmp;
          i_glin(src, 0, src->xsize, y, vals);
          for (x = 0; x < src->xsize/2; ++x) {
            tmp = vals[x];
            vals[x] = vals[src->xsize - x - 1];
            vals[src->xsize - x - 1] = tmp;
          }
          i_plin(targ, 0, src->xsize, src->ysize - y - 1, vals);
        }
        myfree(vals);
      }
      else {
        i_fcolor *vals = mymalloc(src->xsize * sizeof(i_fcolor));
        for (y = 0; y < src->ysize; ++y) {
          i_fcolor tmp;
          i_glinf(src, 0, src->xsize, y, vals);
          for (x = 0; x < src->xsize/2; ++x) {
            tmp = vals[x];
            vals[x] = vals[src->xsize - x - 1];
            vals[src->xsize - x - 1] = tmp;
          }
          i_plinf(targ, 0, src->xsize, src->ysize - y - 1, vals);
        }
        myfree(vals);
      }
    }
    else {
      i_palidx *vals = mymalloc(src->xsize * sizeof(i_palidx));

      for (y = 0; y < src->ysize; ++y) {
        i_palidx tmp;
        i_gpal(src, 0, src->xsize, y, vals);
        for (x = 0; x < src->xsize/2; ++x) {
          tmp = vals[x];
          vals[x] = vals[src->xsize - x - 1];
          vals[src->xsize - x - 1] = tmp;
        }
        i_ppal(targ, 0, src->xsize, src->ysize - y - 1, vals);
      }
      
      myfree(vals);
    }

    return targ;
  }
  else if (degrees == 270 || degrees == 90) {
    i_img_dim tx, txstart, txinc;
    i_img_dim ty, tystart, tyinc;

    if (degrees == 270) {
      txstart = 0;
      txinc = 1;
      tystart = src->xsize-1;
      tyinc = -1;
    }
    else {
      txstart = src->ysize-1;
      txinc = -1;
      tystart = 0;
      tyinc = 1;
    }
    targ = i_sametype(src, src->ysize, src->xsize);
    if (src->type == i_direct_type) {
      if (src->bits == i_8_bits) {
        i_color *vals = mymalloc(src->xsize * sizeof(i_color));

        tx = txstart;
        for (y = 0; y < src->ysize; ++y) {
          i_glin(src, 0, src->xsize, y, vals);
          ty = tystart;
          for (x = 0; x < src->xsize; ++x) {
            i_ppix(targ, tx, ty, vals+x);
            ty += tyinc;
          }
          tx += txinc;
        }
        myfree(vals);
      }
      else {
        i_fcolor *vals = mymalloc(src->xsize * sizeof(i_fcolor));

        tx = txstart;
        for (y = 0; y < src->ysize; ++y) {
          i_glinf(src, 0, src->xsize, y, vals);
          ty = tystart;
          for (x = 0; x < src->xsize; ++x) {
            i_ppixf(targ, tx, ty, vals+x);
            ty += tyinc;
          }
          tx += txinc;
        }
        myfree(vals);
      }
    }
    else {
      i_palidx *vals = mymalloc(src->xsize * sizeof(i_palidx));
      
      tx = txstart;
      for (y = 0; y < src->ysize; ++y) {
        i_gpal(src, 0, src->xsize, y, vals);
        ty = tystart;
        for (x = 0; x < src->xsize; ++x) {
          i_ppal(targ, tx, tx+1, ty, vals+x);
          ty += tyinc;
        }
        tx += txinc;
      }
      myfree(vals);
    }
    return targ;
  }
  else {
    i_push_error(0, "i_rotate90() only rotates at 90, 180, or 270 degrees");
    return NULL;
  }
}

/* linear interpolation */
static i_color interp_i_color(i_color before, i_color after, double pos,
                              int channels) {
  i_color out;
  int ch;

  pos -= floor(pos);
  if (channels == 1 || channels == 3) {
    for (ch = 0; ch < channels; ++ch)
      out.channel[ch] = (1-pos) * before.channel[ch] + pos * after.channel[ch];
  }
  else {
    int total_cover = (1-pos) * before.channel[channels-1]
      + pos * after.channel[channels-1];

    total_cover = I_LIMIT_8(total_cover);
    if (total_cover) {
      double before_alpha = before.channel[channels-1] / 255.0;
      double after_alpha = after.channel[channels-1] / 255.0;
      double total_alpha = before_alpha * (1-pos) + after_alpha * pos;

      for (ch = 0; ch < channels-1; ++ch) {
	int out_level = ((1-pos) * before.channel[ch] * before_alpha + 
			 pos * after.channel[ch] * after_alpha + 0.5) / total_alpha;

	out.channel[ch] = I_LIMIT_8(out_level);
      }
    }

    out.channel[channels-1] = total_cover;
  }

  return out;
}

/* hopefully this will be inlined  (it is with -O3 with gcc 2.95.4) */
/* linear interpolation */
static i_fcolor interp_i_fcolor(i_fcolor before, i_fcolor after, double pos,
                                int channels) {
  i_fcolor out;
  int ch;

  pos -= floor(pos);
  if (channels == 1 || channels == 3) {
    for (ch = 0; ch < channels; ++ch)
      out.channel[ch] = (1-pos) * before.channel[ch] + pos * after.channel[ch];
  }
  else {
    double total_cover = (1-pos) * before.channel[channels-1]
      + pos * after.channel[channels-1];

    total_cover = I_LIMIT_DOUBLE(total_cover);
    if (total_cover) {
      double before_alpha = before.channel[channels-1];
      double after_alpha = after.channel[channels-1];
      double total_alpha = before_alpha * (1-pos) + after_alpha * pos;

      for (ch = 0; ch < channels-1; ++ch) {
	double out_level = ((1-pos) * before.channel[ch] * before_alpha + 
			 pos * after.channel[ch] * after_alpha) / total_alpha;

	out.channel[ch] = I_LIMIT_DOUBLE(out_level);
      }
    }

    out.channel[channels-1] = total_cover;
  }

  return out;
}

i_img *i_matrix_transform_bg(i_img *src, i_img_dim xsize, i_img_dim ysize, const double *matrix,
			     const i_color *backp, const i_fcolor *fbackp) {
  i_img *result = i_sametype(src, xsize, ysize);
  i_img_dim x, y;
  int ch;
  i_img_dim i, j;
  double sx, sy, sz;

  if (src->type == i_direct_type) {
    if (src->bits == i_8_bits) {
      i_color *vals = mymalloc(xsize * sizeof(i_color));
      i_color back;
      i_fsample_t fsamp;

      if (backp) {
	back = *backp;
      }
      else if (fbackp) {
	for (ch = 0; ch < src->channels; ++ch) {
	  fsamp = fbackp->channel[ch];
	  back.channel[ch] = fsamp < 0 ? 0 : fsamp > 1 ? 255 : fsamp * 255;
	}
      }
      else {
	for (ch = 0; ch < src->channels; ++ch)
	  back.channel[ch] = 0;
      }

      for (y = 0; y < ysize; ++y) {
        for (x = 0; x < xsize; ++x) {
          /* dividing by sz gives us the ability to do perspective 
             transforms */
          sz = x * matrix[6] + y * matrix[7] + matrix[8];
          if (fabs(sz) > 0.0000001) {
            sx = (x * matrix[0] + y * matrix[1] + matrix[2]) / sz;
            sy = (x * matrix[3] + y * matrix[4] + matrix[5]) / sz;
          }
	  else {
	    sx = sy = 0;
	  }

          /* anything outside these ranges is either a broken co-ordinate
             or outside the source */
          if (fabs(sz) > 0.0000001 
              && sx >= -1 && sx < src->xsize
              && sy >= -1 && sy < src->ysize) {

            if (sx != (i_img_dim)sx) {
              if (sy != (i_img_dim)sy) {
                i_color c[2][2]; 
                i_color ci2[2];
                for (i = 0; i < 2; ++i)
                  for (j = 0; j < 2; ++j)
                    if (i_gpix(src, floor(sx)+i, floor(sy)+j, &c[j][i]))
                      c[j][i] = back;
                for (j = 0; j < 2; ++j)
                  ci2[j] = interp_i_color(c[j][0], c[j][1], sx, src->channels);
                vals[x] = interp_i_color(ci2[0], ci2[1], sy, src->channels);
              }
              else {
                i_color ci2[2];
                for (i = 0; i < 2; ++i)
                  if (i_gpix(src, floor(sx)+i, sy, ci2+i))
                    ci2[i] = back;
                vals[x] = interp_i_color(ci2[0], ci2[1], sx, src->channels);
              }
            }
            else {
              if (sy != (i_img_dim)sy) {
                i_color ci2[2];
                for (i = 0; i < 2; ++i)
                  if (i_gpix(src, sx, floor(sy)+i, ci2+i))
                    ci2[i] = back;
                vals[x] = interp_i_color(ci2[0], ci2[1], sy, src->channels);
              }
              else {
                /* all the world's an integer */
                if (i_gpix(src, sx, sy, vals+x))
		  vals[x] = back;
              }
            }
          }
          else {
            vals[x] = back;
          }
        }
        i_plin(result, 0, xsize, y, vals);
      }
      myfree(vals);
    }
    else {
      i_fcolor *vals = mymalloc(xsize * sizeof(i_fcolor));
      i_fcolor back;

      if (fbackp) {
	back = *fbackp;
      }
      else if (backp) {
	for (ch = 0; ch < src->channels; ++ch)
	  back.channel[ch] = backp->channel[ch] / 255.0;
      }
      else {
	for (ch = 0; ch < src->channels; ++ch)
	  back.channel[ch] = 0;
      }

      for (y = 0; y < ysize; ++y) {
        for (x = 0; x < xsize; ++x) {
          /* dividing by sz gives us the ability to do perspective 
             transforms */
          sz = x * matrix[6] + y * matrix[7] + matrix[8];
          if (fabs(sz) > 0.0000001) {
            sx = (x * matrix[0] + y * matrix[1] + matrix[2]) / sz;
            sy = (x * matrix[3] + y * matrix[4] + matrix[5]) / sz;
          }
          else {
            sx = sy = 0;
          }

          /* anything outside these ranges is either a broken co-ordinate
             or outside the source */
          if (fabs(sz) > 0.0000001 
              && sx >= -1 && sx < src->xsize
              && sy >= -1 && sy < src->ysize) {

            if (sx != (i_img_dim)sx) {
              if (sy != (i_img_dim)sy) {
                i_fcolor c[2][2]; 
                i_fcolor ci2[2];
                for (i = 0; i < 2; ++i)
                  for (j = 0; j < 2; ++j)
                    if (i_gpixf(src, floor(sx)+i, floor(sy)+j, &c[j][i]))
                      c[j][i] = back;
                for (j = 0; j < 2; ++j)
                  ci2[j] = interp_i_fcolor(c[j][0], c[j][1], sx, src->channels);
                vals[x] = interp_i_fcolor(ci2[0], ci2[1], sy, src->channels);
              }
              else {
                i_fcolor ci2[2];
                for (i = 0; i < 2; ++i)
                  if (i_gpixf(src, floor(sx)+i, sy, ci2+i))
                    ci2[i] = back;
                vals[x] = interp_i_fcolor(ci2[0], ci2[1], sx, src->channels);
              }
            }
            else {
              if (sy != (i_img_dim)sy) {
                i_fcolor ci2[2];
                for (i = 0; i < 2; ++i)
                  if (i_gpixf(src, sx, floor(sy)+i, ci2+i))
                    ci2[i] = back;
                vals[x] = interp_i_fcolor(ci2[0], ci2[1], sy, src->channels);
              }
              else {
                /* all the world's an integer */
                if (i_gpixf(src, sx, sy, vals+x)) 
		  vals[x] = back;
              }
            }
          }
          else {
            vals[x] = back;
          }
        }
        i_plinf(result, 0, xsize, y, vals);
      }
      myfree(vals);
    }
  }
  else {
    /* don't interpolate for a palette based image */
    i_palidx *vals = mymalloc(xsize * sizeof(i_palidx));
    i_palidx back = 0;
    i_color min;
    int minval = 256 * 4;
    i_img_dim ix, iy;
    i_color want_back;
    i_fsample_t fsamp;

    if (backp) {
      want_back = *backp;
    }
    else if (fbackp) {
      for (ch = 0; ch < src->channels; ++ch) {
	fsamp = fbackp->channel[ch];
	want_back.channel[ch] = fsamp < 0 ? 0 : fsamp > 1 ? 255 : fsamp * 255;
      }
    }
    else {
      for (ch = 0; ch < src->channels; ++ch)
	want_back.channel[ch] = 0;
    }
    
    /* find the closest color */
    for (i = 0; i < i_colorcount(src); ++i) {
      i_color temp;
      int tempval;
      i_getcolors(src, i, &temp, 1);
      tempval = 0;
      for (ch = 0; ch < src->channels; ++ch) {
        tempval += abs(want_back.channel[ch] - temp.channel[ch]);
      }
      if (tempval < minval) {
        back = i;
        min = temp;
        minval = tempval;
      }
    }

    for (y = 0; y < ysize; ++y) {
      for (x = 0; x < xsize; ++x) {
        /* dividing by sz gives us the ability to do perspective 
           transforms */
        sz = x * matrix[6] + y * matrix[7] + matrix[8];
        if (abs(sz) > 0.0000001) {
          sx = (x * matrix[0] + y * matrix[1] + matrix[2]) / sz;
          sy = (x * matrix[3] + y * matrix[4] + matrix[5]) / sz;
        }
        else {
          sx = sy = 0;
        }
        
        /* anything outside these ranges is either a broken co-ordinate
           or outside the source */
        if (abs(sz) > 0.0000001 
            && sx >= -0.5 && sx < src->xsize-0.5
            && sy >= -0.5 && sy < src->ysize-0.5) {
          
          /* all the world's an integer */
          ix = (i_img_dim)(sx+0.5);
          iy = (i_img_dim)(sy+0.5);
          if (!i_gpal(src, ix, ix+1, iy, vals+x))
	    vals[i] = back;
        }
        else {
          vals[x] = back;
        }
      }
      i_ppal(result, 0, xsize, y, vals);
    }
    myfree(vals);
  }

  return result;
}

i_img *i_matrix_transform(i_img *src, i_img_dim xsize, i_img_dim ysize, const double *matrix) {
  return i_matrix_transform_bg(src, xsize, ysize, matrix, NULL, NULL);
}

static void
i_matrix_mult(double *dest, const double *left, const double *right) {
  int i, j, k;
  double accum;
  
  for (i = 0; i < 3; ++i) {
    for (j = 0; j < 3; ++j) {
      accum = 0.0;
      for (k = 0; k < 3; ++k) {
        accum += left[3*i+k] * right[3*k+j];
      }
      dest[3*i+j] = accum;
    }
  }
}

i_img *i_rotate_exact_bg(i_img *src, double amount, 
			 const i_color *backp, const i_fcolor *fbackp) {
  double xlate1[9] = { 0 };
  double rotate[9];
  double xlate2[9] = { 0 };
  double temp[9], matrix[9];
  i_img_dim x1, x2, y1, y2, newxsize, newysize;

  /* first translate the centre of the image to (0,0) */
  xlate1[0] = 1;
  xlate1[2] = src->xsize/2.0;
  xlate1[4] = 1;
  xlate1[5] = src->ysize/2.0;
  xlate1[8] = 1;

  /* rotate around (0.0) */
  rotate[0] = cos(amount);
  rotate[1] = sin(amount);
  rotate[2] = 0;
  rotate[3] = -rotate[1];
  rotate[4] = rotate[0];
  rotate[5] = 0;
  rotate[6] = 0;
  rotate[7] = 0;
  rotate[8] = 1;

  x1 = ceil(i_abs(src->xsize * rotate[0] + src->ysize * rotate[1]));
  x2 = ceil(i_abs(src->xsize * rotate[0] - src->ysize * rotate[1]));
  y1 = ceil(i_abs(src->xsize * rotate[3] + src->ysize * rotate[4]));
  y2 = ceil(i_abs(src->xsize * rotate[3] - src->ysize * rotate[4]));
  newxsize = x1 > x2 ? x1 : x2;
  newysize = y1 > y2 ? y1 : y2;
  /* translate the centre back to the center of the image */
  xlate2[0] = 1;
  xlate2[2] = -newxsize/2.0;
  xlate2[4] = 1;
  xlate2[5] = -newysize/2.0;
  xlate2[8] = 1;
  i_matrix_mult(temp, xlate1, rotate);
  i_matrix_mult(matrix, temp, xlate2);

  return i_matrix_transform_bg(src, newxsize, newysize, matrix, backp, fbackp);
}

i_img *i_rotate_exact(i_img *src, double amount) {
  return i_rotate_exact_bg(src, amount, NULL, NULL);
}


/*
=back

=head1 AUTHOR

Tony Cook <tony@develop-help.com>

=head1 SEE ALSO

Imager(3)

=cut
*/
