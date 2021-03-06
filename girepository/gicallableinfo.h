/* GObject introspection: Callable
 *
 * Copyright (C) 2005 Matthias Clasen
 * Copyright (C) 2008,2009 Red Hat, Inc.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#ifndef __GICALLABLEINFO_H__
#define __GICALLABLEINFO_H__

#if !defined (__GIREPOSITORY_H_INSIDE__) && !defined (GI_COMPILATION)
#error "Only <girepository.h> can be included directly."
#endif

#include <gitypes.h>

G_BEGIN_DECLS

#define GI_IS_CALLABLE_INFO(info)					\
    ((g_base_info_get_type((GIBaseInfo*)info) == GI_INFO_TYPE_FUNCTION) || \
     (g_base_info_get_type((GIBaseInfo*)info) == GI_INFO_TYPE_CALLBACK) || \
     (g_base_info_get_type((GIBaseInfo*)info) == GI_INFO_TYPE_SIGNAL) || \
     (g_base_info_get_type((GIBaseInfo*)info) == GI_INFO_TYPE_VFUNC))

GITypeInfo *           g_callable_info_get_return_type (GICallableInfo *info);
void                   g_callable_info_load_return_type (GICallableInfo *info,
                                                         GITypeInfo     *type);
const gchar *          g_callable_info_get_return_attribute (GICallableInfo *info,
                                                             const gchar    *name);
gboolean               g_callable_info_iterate_return_attributes (GICallableInfo  *info,
                                                                  GIAttributeIter *iterator,
                                                                  char           **name,
                                                                  char          **value);
GITransfer             g_callable_info_get_caller_owns (GICallableInfo *info);
gboolean               g_callable_info_may_return_null (GICallableInfo *info);
gboolean               g_callable_info_skip_return     (GICallableInfo *info);
gint                   g_callable_info_get_n_args      (GICallableInfo *info);
GIArgInfo *            g_callable_info_get_arg         (GICallableInfo *info,
                                                        gint            n);
void                   g_callable_info_load_arg        (GICallableInfo *info,
                                                        gint            n,
                                                        GIArgInfo      *arg);
G_END_DECLS


#endif  /* __GICALLABLEINFO_H__ */

