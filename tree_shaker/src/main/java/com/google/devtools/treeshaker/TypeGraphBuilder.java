/*
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package com.google.devtools.treeshaker;

import static com.google.common.base.Preconditions.checkNotNull;

import java.util.Collection;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;

/** Give information about inheritance relationships between types. */
class TypeGraphBuilder {
  private final Collection<Type> types;
  private final Set<String> externalTypeReferences;

  TypeGraphBuilder(LibraryInfo libraryInfo) {
    Map<String, Type> typesByName = new LinkedHashMap<>();
    externalTypeReferences = new HashSet<>();
    for (TypeInfo typeInfo : libraryInfo.getTypeList()) {
      Type type = Type.buildFrom(typeInfo, libraryInfo.getTypeMap(typeInfo.getTypeId()));
      typesByName.put(type.getName(), type);
    }
    // Build cross-references between types and members
    buildCrossReferences(libraryInfo, typesByName);
    types = typesByName.values();
  }

  Collection<Type> getTypes() {
    return types;
  }

  Collection<String> getExternalTypeReferences() {
    return externalTypeReferences;
  }

  private void buildCrossReferences(LibraryInfo libraryInfo, Map<String, Type> typesByName) {
    for (TypeInfo typeInfo : libraryInfo.getTypeList()) {
      Type type = typesByName.get(libraryInfo.getTypeMap(typeInfo.getTypeId()));
      int extendsId = typeInfo.getExtendsType();
      String superClassName = libraryInfo.getTypeMap(extendsId);
      Type superClass = typesByName.get(superClassName);

      if (superClass != null) {
        superClass.addImmediateSubtype(type);
        type.setSuperClass(superClass);
      } else {
        externalTypeReferences.add(superClassName);
      }

      for (int implementsId : typeInfo.getImplementsTypeList()) {
        Type superInterface = typesByName.get(libraryInfo.getTypeMap(implementsId));
        if (superInterface == null) {
          externalTypeReferences.add(libraryInfo.getTypeMap(implementsId));
        } else {
          superInterface.addImmediateSubtype(type);
          type.addSuperInterface(superInterface);
        }
      }

      for (MemberInfo memberInfo : typeInfo.getMemberList()) {
        Member member = type.getMemberByName(memberInfo.getName());

        for (int referencedId : memberInfo.getReferencedTypesList()) {
          Type referencedType = typesByName.get(libraryInfo.getTypeMap(referencedId));
          if (referencedType == null) {
            externalTypeReferences.add(libraryInfo.getTypeMap(referencedId));
            continue;
          }
          member.addReferencedType(checkNotNull(referencedType));
        }

        for (MethodInvocation methodInvocation : memberInfo.getInvokedMethodsList()) {
          Type enclosingType =
              typesByName.get(libraryInfo.getTypeMap(methodInvocation.getEnclosingType()));
          if (enclosingType != null) {
            Member referencedMember = enclosingType.getMemberByName(methodInvocation.getMethod());
            member.addReferencedMember(checkNotNull(referencedMember));
          } else {
            externalTypeReferences.add(libraryInfo.getTypeMap(methodInvocation.getEnclosingType()));
          }
        }
      }
    }
  }
}
