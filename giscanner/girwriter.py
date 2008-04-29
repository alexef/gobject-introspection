# -*- Mode: Python -*-
# GObject-Introspection - a framework for introspecting GObject libraries
# Copyright (C) 2008  Johan Dahlin
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301, USA.
#

from __future__ import with_statement

from .ast import (Callback, Class, Enum, Function, Interface, Sequence,
                  Struct)
from .glibast import (GLibBoxed, GLibEnum, GLibEnumMember,
                      GLibFlags, GLibObject, GLibInterface)
from .xmlwriter import XMLWriter


class GIRWriter(XMLWriter):
    def __init__(self, namespace, nodes):
        super(GIRWriter, self).__init__()
        self._write_repository(namespace, nodes)

    def _write_repository(self, namespace, nodes):
        attrs = [
            ('version', '1.0'),
            ('xmlns', 'http://www.gtk.org/introspection/core/1.0'),
            ('xmlns:c', 'http://www.gtk.org/introspection/c/1.0'),
            ('xmlns:glib', 'http://www.gtk.org/introspection/glib/1.0'),
            ]
        with self.tagcontext('repository', attrs):
            self._write_namespace(namespace, nodes)

    def _write_namespace(self, namespace, nodes):
        with self.tagcontext('namespace', [('name', namespace)]):
            for node in nodes:
                self._write_node(node)

    def _write_node(self, node):
        if isinstance(node, Function):
            self._write_function(node)
        elif isinstance(node, Enum):
            self._write_enum(node)
        elif isinstance(node, (Class, Interface)):
            self._write_class(node)
        elif isinstance(node, GLibBoxed):
            self._write_boxed(node)
        elif isinstance(node, Callback):
            self._write_callback(node)
        elif isinstance(node, Struct):
            self._write_record(node)
        else:
            print 'WRITER: Unhandled node', node

    def _write_function(self, func, tag_name='function'):
        attrs = [('name', func.name),
                 ('c:identifier', func.symbol)]
        with self.tagcontext(tag_name, attrs):
            self._write_return_type(func.retval)
            self._write_parameters(func.parameters)

    def _write_method(self, method):
        self._write_function(method, tag_name='method')

    def _write_constructor(self, method):
        self._write_function(method, tag_name='constructor')

    def _write_return_type(self, return_):
        if not return_:
            return
        with self.tagcontext('return-value'):
            if isinstance(return_.type, Sequence):
                self._write_sequence(return_.type)
            else:
                self._write_type(return_.type)

    def _write_parameters(self, parameters):
        if not parameters:
            return
        with self.tagcontext('parameters'):
            for parameter in parameters:
                self._write_parameter(parameter)

    def _write_parameter(self, parameter):
        attrs = [('name', parameter.name)]
        if parameter.direction != 'in':
            attrs.append(('direction', parameter.direction))
        if parameter.transfer != 'none':
            attrs.append(('transfer', parameter.transfer))
        with self.tagcontext('parameter', attrs):
            self._write_type(parameter.type)

    def _write_type(self, type):
        attrs = [('name', type.name)]
        # FIXME: figure out if type references a basic type
        #        or a boxed/class/interface etc. and skip
        #        writing the ctype if the latter.
        if 1:
            attrs.append(('c:type', type.ctype))
        self.write_tag('type', attrs)

    def _write_sequence(self, sequence):
        attrs = [('c:owner', sequence.cowner)]
        with self.tagcontext('sequence', attrs):
            attrs = [('c:identifier', sequence.element_type)]
            self.write_tag('element-type', attrs)

    def _write_enum(self, enum):
        attrs = [('name', enum.name),
                 ('c:type', enum.ctype)]
        tag_name = 'enumeration'
        if isinstance(enum, GLibEnum):
            attrs.extend([('glib:type-name', enum.type_name),
                          ('glib:get-type', enum.get_type)])
            if isinstance(enum, GLibFlags):
                tag_name = 'bitfield'

        with self.tagcontext(tag_name, attrs):
            for member in enum.members:
                self._write_member(member)

    def _write_member(self, member):
        attrs = [('name', member.name),
                 ('value', str(member.value))]
        if isinstance(member, GLibEnumMember):
            attrs.append(('glib:nick', member.nick))
        self.write_tag('member', attrs)

    def _write_class(self, node):
        attrs = [('name', node.name),
                 ('c:type', node.ctype)]
        if isinstance(node, Class):
            tag_name = 'class'
            if node.parent is not None:
                attrs.append(('parent', node.parent))
        else:
            tag_name = 'interface'
        if isinstance(node, (GLibObject, GLibInterface)):
            attrs.append(('glib:type-name', node.type_name))
            attrs.append(('glib:get-type', node.get_type))
        with self.tagcontext(tag_name, attrs):
            if isinstance(node, Class):
                for method in node.constructors:
                    self._write_constructor(method)
            for method in node.methods:
                self._write_method(method)
            for prop in node.properties:
                self._write_property(prop)
            for field in node.fields:
                self._write_field(field)
            for signal in node.signals:
                self._write_signal(signal)

    def _write_boxed(self, boxed):
        attrs = [('c:type', boxed.ctype),
                 ('glib:name', boxed.name),
                 ('glib:type-name', boxed.type_name),
                 ('glib:get-type', boxed.get_type)]

        with self.tagcontext('glib:boxed', attrs):
            for method in boxed.constructors:
                self._write_constructor(method)
            for method in boxed.methods:
                self._write_method(method)

    def _write_property(self, prop):
        attrs = [('name', prop.name)]
        with self.tagcontext('property', attrs):
            self._write_type(prop.type)

    def _write_callback(self, callback):
        attrs = [('name', callback.name)]
        with self.tagcontext('callback', attrs):
            self._write_return_type(callback.retval)
            self._write_parameters(callback.parameters)

    def _write_record(self, record):
        attrs = [('name', record.name),
                 ('c:type', record.symbol)]
        if record.fields:
            with self.tagcontext('record', attrs):
                for field in record.fields:
                    self._write_field(field)
        else:
            self.write_tag('record', attrs)

    def _write_field(self, field):
        if isinstance(field, Callback):
            self._write_callback(field)
            return

        attrs = [('name', field.name),
                 ('type', str(field.type))]
        self.write_tag('field', attrs)

    def _write_signal(self, signal):
        attrs = [('name', signal.name)]
        with self.tagcontext('glib:signal', attrs):
            self._write_return_type(signal.retval)
            self._write_parameters(signal.parameters)
