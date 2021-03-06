# -*- Mode: Python -*-
# GObject-Introspection - a framework for introspecting GObject libraries
# Copyright (C) 2008  Johan Dahlin
# Copyright (C) 2008, 2009 Red Hat, Inc.
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the
# Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA.
#

from __future__ import with_statement

from . import ast
from .xmlwriter import XMLWriter

# Bump this for *incompatible* changes to the .gir.
# Compatible changes we just make inline
COMPATIBLE_GIR_VERSION = '1.2'

class GIRWriter(XMLWriter):

    def __init__(self, namespace, shlibs, includes, pkgs, c_includes):
        super(GIRWriter, self).__init__()
        self.write_comment(
'''This file was automatically generated from C sources - DO NOT EDIT!
To affect the contents of this file, edit the original C definitions,
and/or use gtk-doc annotations. ''')
        self._write_repository(namespace, shlibs, includes, pkgs,
                               c_includes)

    def _write_repository(self, namespace, shlibs, includes=None,
                          packages=None, c_includes=None):
        if includes is None:
            includes = frozenset()
        if packages is None:
            packages = frozenset()
        if c_includes is None:
            c_includes = frozenset()
        attrs = [
            ('version', COMPATIBLE_GIR_VERSION),
            ('xmlns', 'http://www.gtk.org/introspection/core/1.0'),
            ('xmlns:c', 'http://www.gtk.org/introspection/c/1.0'),
            ('xmlns:glib', 'http://www.gtk.org/introspection/glib/1.0'),
            ]
        with self.tagcontext('repository', attrs):
            for include in sorted(includes):
                self._write_include(include)
            for pkg in sorted(set(packages)):
                self._write_pkgconfig_pkg(pkg)
            for c_include in sorted(set(c_includes)):
                self._write_c_include(c_include)
            self._namespace = namespace
            self._write_namespace(namespace, shlibs)
            self._namespace = None

    def _write_include(self, include):
        attrs = [('name', include.name), ('version', include.version)]
        self.write_tag('include', attrs)

    def _write_pkgconfig_pkg(self, package):
        attrs = [('name', package)]
        self.write_tag('package', attrs)

    def _write_c_include(self, c_include):
        attrs = [('name', c_include)]
        self.write_tag('c:include', attrs)

    def _write_namespace(self, namespace, shlibs):
        attrs = [('name', namespace.name),
                 ('version', namespace.version),
                 ('shared-library', ','.join(shlibs)),
                 ('c:identifier-prefixes', ','.join(namespace.identifier_prefixes)),
                 ('c:symbol-prefixes', ','.join(namespace.symbol_prefixes))]
        with self.tagcontext('namespace', attrs):
            # We define a custom sorting function here because
            # we want aliases to be first.  They're a bit
            # special because the typelib compiler expands them.
            def nscmp(a, b):
                if isinstance(a, ast.Alias):
                    if isinstance(b, ast.Alias):
                        return cmp(a.name, b.name)
                    else:
                        return -1
                elif isinstance(b, ast.Alias):
                    return 1
                else:
                    return cmp(a, b)
            for node in sorted(namespace.itervalues(), cmp=nscmp):
                self._write_node(node)

    def _write_node(self, node):
        if isinstance(node, ast.Function):
            self._write_function(node)
        elif isinstance(node, ast.Enum):
            self._write_enum(node)
        elif isinstance(node, ast.Bitfield):
            self._write_bitfield(node)
        elif isinstance(node, (ast.Class, ast.Interface)):
            self._write_class(node)
        elif isinstance(node, ast.Callback):
            self._write_callback(node)
        elif isinstance(node, ast.Record):
            self._write_record(node)
        elif isinstance(node, ast.Union):
            self._write_union(node)
        elif isinstance(node, ast.Boxed):
            self._write_boxed(node)
        elif isinstance(node, ast.Member):
            # FIXME: atk_misc_instance singleton
            pass
        elif isinstance(node, ast.Alias):
            self._write_alias(node)
        elif isinstance(node, ast.Constant):
            self._write_constant(node)
        else:
            print 'WRITER: Unhandled node', node

    def _append_version(self, node, attrs):
        if node.version:
            attrs.append(('version', node.version))

    def _write_generic(self, node):
        for key, value in node.attributes:
            self.write_tag('attribute', [('name', key), ('value', value)])
        if hasattr(node, 'doc') and node.doc:
            self.write_tag('doc', [('xml:whitespace', 'preserve')],
                           node.doc.strip())

    def _append_node_generic(self, node, attrs):
        if node.skip or not node.introspectable:
            attrs.append(('introspectable', '0'))
        if node.deprecated:
            attrs.append(('deprecated', node.deprecated))
            if node.deprecated_version:
                attrs.append(('deprecated-version',
                              node.deprecated_version))

    def _append_throws(self, func, attrs):
        if func.throws:
            attrs.append(('throws', '1'))

    def _write_alias(self, alias):
        attrs = [('name', alias.name)]
        if alias.ctype is not None:
            attrs.append(('c:type', alias.ctype))
        self._append_node_generic(alias, attrs)
        with self.tagcontext('alias', attrs):
            self._write_generic(alias)
            self._write_type_ref(alias.target)

    def _write_callable(self, callable, tag_name, extra_attrs):
        attrs = [('name', callable.name)]
        attrs.extend(extra_attrs)
        self._append_version(callable, attrs)
        self._append_node_generic(callable, attrs)
        self._append_throws(callable, attrs)
        with self.tagcontext(tag_name, attrs):
            self._write_generic(callable)
            self._write_return_type(callable.retval, parent=callable)
            self._write_parameters(callable, callable.parameters)

    def _write_function(self, func, tag_name='function'):
        attrs = []
        if hasattr(func, 'symbol'):
            attrs.append(('c:identifier', func.symbol))
        if func.shadowed_by:
            attrs.append(('shadowed-by', func.shadowed_by))
        elif func.shadows:
            attrs.append(('shadows', func.shadows))
        self._write_callable(func, tag_name, attrs)

    def _write_method(self, method):
        self._write_function(method, tag_name='method')

    def _write_static_method(self, method):
        self._write_function(method, tag_name='function')

    def _write_constructor(self, method):
        self._write_function(method, tag_name='constructor')

    def _write_return_type(self, return_, parent=None):
        if not return_:
            return

        attrs = []
        if return_.transfer:
            attrs.append(('transfer-ownership', return_.transfer))
        if return_.skip:
            attrs.append(('skip', '1'))
        with self.tagcontext('return-value', attrs):
            self._write_generic(return_)
            self._write_type(return_.type, function=parent)

    def _write_parameters(self, parent, parameters):
        if not parameters:
            return
        with self.tagcontext('parameters'):
            for parameter in parameters:
                self._write_parameter(parent, parameter)

    def _write_parameter(self, parent, parameter):
        attrs = []
        if parameter.argname is not None:
            attrs.append(('name', parameter.argname))
        if (parameter.direction is not None) and (parameter.direction != 'in'):
            attrs.append(('direction', parameter.direction))
            attrs.append(('caller-allocates',
                          '1' if parameter.caller_allocates else '0'))
        if parameter.transfer:
            attrs.append(('transfer-ownership',
                          parameter.transfer))
        if parameter.allow_none:
            attrs.append(('allow-none', '1'))
        if parameter.scope:
            attrs.append(('scope', parameter.scope))
        if parameter.closure_name is not None:
            idx = parent.get_parameter_index(parameter.closure_name)
            attrs.append(('closure', '%d' % (idx, )))
        if parameter.destroy_name is not None:
            idx = parent.get_parameter_index(parameter.destroy_name)
            attrs.append(('destroy', '%d' % (idx, )))
        if parameter.skip:
            attrs.append(('skip', '1'))
        with self.tagcontext('parameter', attrs):
            self._write_generic(parameter)
            self._write_type(parameter.type, function=parent)

    def _type_to_name(self, typeval):
        if not typeval.resolved:
            raise AssertionError("Caught unresolved type %r (ctype=%r)" % (typeval, typeval.ctype))
        assert typeval.target_giname is not None
        prefix = self._namespace.name + '.'
        if typeval.target_giname.startswith(prefix):
            return typeval.target_giname[len(prefix):]
        return typeval.target_giname

    def _write_type_ref(self, ntype):
        """ Like _write_type, but only writes the type name rather than the full details """
        assert isinstance(ntype, ast.Type), ntype
        attrs = []
        if ntype.ctype:
            attrs.append(('c:type', ntype.ctype))
        if isinstance(ntype, ast.Array):
            if ntype.array_type != ast.Array.C:
                attrs.insert(0, ('name', ntype.array_type))
        elif isinstance(ntype, ast.List):
            if ntype.name:
                attrs.insert(0, ('name', ntype.name))
        elif isinstance(ntype, ast.Map):
            attrs.insert(0, ('name', 'GLib.HashTable'))
        else:
            if ntype.target_giname:
                attrs.insert(0, ('name', self._type_to_name(ntype)))
            elif ntype.target_fundamental:
                attrs.insert(0, ('name', ntype.target_fundamental))

        self.write_tag('type', attrs)

    def _write_type(self, ntype, relation=None, function=None):
        assert isinstance(ntype, ast.Type), ntype
        attrs = []
        if ntype.ctype:
            attrs.append(('c:type', ntype.ctype))
        if isinstance(ntype, ast.Varargs):
            with self.tagcontext('varargs', []):
                pass
        elif isinstance(ntype, ast.Array):
            if ntype.array_type != ast.Array.C:
                attrs.insert(0, ('name', ntype.array_type))
            # we insert an explicit 'zero-terminated' attribute
            # when it is false, or when it would not be implied
            # by the absence of length and fixed-size
            if not ntype.zeroterminated:
                attrs.insert(0, ('zero-terminated', '0'))
            elif (ntype.zeroterminated
                  and (ntype.size is not None or ntype.length_param_name is not None)):
                attrs.insert(0, ('zero-terminated', '1'))
            if ntype.size is not None:
                attrs.append(('fixed-size', '%d' % (ntype.size, )))
            if ntype.length_param_name is not None:
                assert function
                attrs.insert(0, ('length', '%d'
                            % (function.get_parameter_index(ntype.length_param_name, ))))

            with self.tagcontext('array', attrs):
                self._write_type(ntype.element_type)
        elif isinstance(ntype, ast.List):
            if ntype.name:
                attrs.insert(0, ('name', ntype.name))
            with self.tagcontext('type', attrs):
                self._write_type(ntype.element_type)
        elif isinstance(ntype, ast.Map):
            attrs.insert(0, ('name', 'GLib.HashTable'))
            with self.tagcontext('type', attrs):
                self._write_type(ntype.key_type)
                self._write_type(ntype.value_type)
        else:
            # REWRITEFIXME - enable this for 1.2
            if ntype.target_giname:
                attrs.insert(0, ('name', self._type_to_name(ntype)))
            elif ntype.target_fundamental:
                # attrs = [('fundamental', ntype.target_fundamental)]
                attrs.insert(0, ('name', ntype.target_fundamental))
            elif ntype.target_foreign:
                attrs.insert(0, ('foreign', '1'))
            self.write_tag('type', attrs)

    def _append_registered(self, node, attrs):
        assert isinstance(node, ast.Registered)
        if node.get_type:
            attrs.extend([('glib:type-name', node.gtype_name),
                          ('glib:get-type', node.get_type)])

    def _write_enum(self, enum):
        attrs = [('name', enum.name)]
        self._append_version(enum, attrs)
        self._append_node_generic(enum, attrs)
        self._append_registered(enum, attrs)
        attrs.append(('c:type', enum.ctype))
        if enum.error_quark:
            attrs.append(('glib:error-quark', enum.error_quark))

        with self.tagcontext('enumeration', attrs):
            self._write_generic(enum)
            for member in enum.members:
                self._write_member(member)

    def _write_bitfield(self, bitfield):
        attrs = [('name', bitfield.name)]
        self._append_version(bitfield, attrs)
        self._append_node_generic(bitfield, attrs)
        self._append_registered(bitfield, attrs)
        attrs.append(('c:type', bitfield.ctype))
        with self.tagcontext('bitfield', attrs):
            self._write_generic(bitfield)
            for member in bitfield.members:
                self._write_member(member)

    def _write_member(self, member):
        attrs = [('name', member.name),
                 ('value', str(member.value)),
                 ('c:identifier', member.symbol)]
        if member.nick is not None:
            attrs.append(('glib:nick', member.nick))
        self.write_tag('member', attrs)

    def _write_constant(self, constant):
        attrs = [('name', constant.name), ('value', constant.value)]
        with self.tagcontext('constant', attrs):
            self._write_type(constant.value_type)

    def _write_class(self, node):
        attrs = [('name', node.name),
                 ('c:symbol-prefix', node.c_symbol_prefix),
                 ('c:type', node.ctype)]
        self._append_version(node, attrs)
        self._append_node_generic(node, attrs)
        if isinstance(node, ast.Class):
            tag_name = 'class'
            if node.parent is not None:
                attrs.append(('parent',
                              self._type_to_name(node.parent)))
            if node.is_abstract:
                attrs.append(('abstract', '1'))
        else:
            assert isinstance(node, ast.Interface)
            tag_name = 'interface'
        attrs.append(('glib:type-name', node.gtype_name))
        if node.get_type is not None:
            attrs.append(('glib:get-type', node.get_type))
        if node.glib_type_struct is not None:
            attrs.append(('glib:type-struct',
                          self._type_to_name(node.glib_type_struct)))
        if isinstance(node, ast.Class):
            if node.fundamental:
                attrs.append(('glib:fundamental', '1'))
            if node.ref_func:
                attrs.append(('glib:ref-func', node.ref_func))
            if node.unref_func:
                attrs.append(('glib:unref-func', node.unref_func))
            if node.set_value_func:
                attrs.append(('glib:set-value-func', node.set_value_func))
            if node.get_value_func:
                attrs.append(('glib:get-value-func', node.get_value_func))
        with self.tagcontext(tag_name, attrs):
            self._write_generic(node)
            if isinstance(node, ast.Class):
                for iface in sorted(node.interfaces):
                    self.write_tag('implements',
                                   [('name', self._type_to_name(iface))])
            if isinstance(node, ast.Interface):
                for iface in sorted(node.prerequisites):
                    self.write_tag('prerequisite',
                                   [('name', self._type_to_name(iface))])
            if isinstance(node, ast.Class):
                for method in sorted(node.constructors):
                    self._write_constructor(method)
            if isinstance(node, (ast.Class, ast.Interface)):
                for method in sorted(node.static_methods):
                    self._write_static_method(method)
            for vfunc in sorted(node.virtual_methods):
                self._write_vfunc(vfunc)
            for method in sorted(node.methods):
                self._write_method(method)
            for prop in sorted(node.properties):
                self._write_property(prop)
            for field in node.fields:
                self._write_field(field)
            for signal in sorted(node.signals):
                self._write_signal(signal)

    def _write_boxed(self, boxed):
        attrs = [('glib:name', boxed.name)]
        if boxed.c_symbol_prefix is not None:
            attrs.append(('c:symbol-prefix', boxed.c_symbol_prefix))
        self._append_registered(boxed, attrs)
        with self.tagcontext('glib:boxed', attrs):
            self._write_generic(boxed)
            for method in sorted(boxed.constructors):
                self._write_constructor(method)
            for method in sorted(boxed.methods):
                self._write_method(method)
            for method in sorted(boxed.static_methods):
                self._write_static_method(method)

    def _write_property(self, prop):
        attrs = [('name', prop.name)]
        self._append_version(prop, attrs)
        self._append_node_generic(prop, attrs)
        # Properties are assumed to be readable (see also generate.c)
        if not prop.readable:
            attrs.append(('readable', '0'))
        if prop.writable:
            attrs.append(('writable', '1'))
        if prop.construct:
            attrs.append(('construct', '1'))
        if prop.construct_only:
            attrs.append(('construct-only', '1'))
        if prop.transfer:
            attrs.append(('transfer-ownership', prop.transfer))
        with self.tagcontext('property', attrs):
            self._write_generic(prop)
            self._write_type(prop.type)

    def _write_vfunc(self, vf):
        attrs = []
        if vf.invoker:
            attrs.append(('invoker', vf.invoker))
        self._write_callable(vf, 'virtual-method', attrs)

    def _write_callback(self, callback):
        attrs = []
        if callback.namespace:
            attrs.append(('c:type', callback.ctype or callback.c_name))
        self._write_callable(callback, 'callback', attrs)

    def _write_record(self, record, extra_attrs=[]):
        is_gtype_struct = False
        attrs = list(extra_attrs)
        if record.name is not None:
            attrs.append(('name', record.name))
        if record.ctype is not None: # the record might be anonymous
            attrs.append(('c:type', record.ctype))
        if record.disguised:
            attrs.append(('disguised', '1'))
        if record.foreign:
            attrs.append(('foreign', '1'))
        if record.is_gtype_struct_for is not None:
            is_gtype_struct = True
            attrs.append(('glib:is-gtype-struct-for',
                          self._type_to_name(record.is_gtype_struct_for)))
        self._append_version(record, attrs)
        self._append_node_generic(record, attrs)
        self._append_registered(record, attrs)
        if record.c_symbol_prefix:
            attrs.append(('c:symbol-prefix', record.c_symbol_prefix))
        with self.tagcontext('record', attrs):
            self._write_generic(record)
            if record.fields:
                for field in record.fields:
                    self._write_field(field, is_gtype_struct)
            for method in sorted(record.constructors):
                self._write_constructor(method)
            for method in sorted(record.methods):
                self._write_method(method)
            for method in sorted(record.static_methods):
                self._write_static_method(method)

    def _write_union(self, union):
        attrs = []
        if union.name is not None:
            attrs.append(('name', union.name))
        if union.ctype is not None: # the union might be anonymous
            attrs.append(('c:type', union.ctype))
        self._append_version(union, attrs)
        self._append_node_generic(union, attrs)
        self._append_registered(union, attrs)
        if union.c_symbol_prefix:
            attrs.append(('c:symbol-prefix', union.c_symbol_prefix))
        with self.tagcontext('union', attrs):
            self._write_generic(union)
            if union.fields:
                for field in union.fields:
                    self._write_field(field)
            for method in sorted(union.constructors):
                self._write_constructor(method)
            for method in sorted(union.methods):
                self._write_method(method)
            for method in sorted(union.static_methods):
                self._write_static_method(method)

    def _write_field(self, field, is_gtype_struct=False):
        if field.anonymous_node:
            if isinstance(field.anonymous_node, ast.Callback):
                attrs = [('name', field.name)]
                self._append_node_generic(field, attrs)
                with self.tagcontext('field', attrs):
                    self._write_callback(field.anonymous_node)
            elif isinstance(field.anonymous_node, ast.Record):
                self._write_record(field.anonymous_node)
            elif isinstance(field.anonymous_node, ast.Union):
                self._write_union(field.anonymous_node)
            else:
                raise AssertionError("Unknown field anonymous: %r" \
                                         % (field.anonymous_node, ))
        else:
            attrs = [('name', field.name)]
            self._append_node_generic(field, attrs)
            # Fields are assumed to be read-only
            # (see also girparser.c and generate.c)
            if not field.readable:
                attrs.append(('readable', '0'))
            if field.writable:
                attrs.append(('writable', '1'))
            if field.bits:
                attrs.append(('bits', str(field.bits)))
            if field.private:
                attrs.append(('private', '1'))
            with self.tagcontext('field', attrs):
                self._write_generic(field)
                self._write_type(field.type)

    def _write_signal(self, signal):
        attrs = [('name', signal.name)]
        self._append_version(signal, attrs)
        self._append_node_generic(signal, attrs)
        with self.tagcontext('glib:signal', attrs):
            self._write_generic(signal)
            self._write_return_type(signal.retval)
            self._write_parameters(signal, signal.parameters)
