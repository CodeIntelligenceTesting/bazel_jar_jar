/**
 * Copyright 2007 Google Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.github.johnynek.jarjar.util;

import java.util.jar.JarEntry;
import java.util.jar.JarFile;
import java.util.jar.JarOutputStream;
import java.util.Enumeration;
import java.io.*;
import java.util.*;

public class StandaloneJarProcessor
{
    public static void run(File from, File to, JarProcessor proc, Boolean warnOnDuplicateClass) throws IOException {
        byte[] buf = new byte[0x2000];

        JarFile in = new JarFile(from);
        final File tmpTo = File.createTempFile("jarjar", ".jar");
        BufferedOutputStream buffered = new BufferedOutputStream(new FileOutputStream(tmpTo));
        JarOutputStream out = new JarOutputStream(buffered);
        Set<String> entries = new HashSet<String>();
        try {
            Enumeration<JarEntry> e = in.entries();
            while (e.hasMoreElements()) {
                EntryStruct struct = new EntryStruct();
                JarEntry entry = e.nextElement();
                struct.name = entry.getName();
                struct.time = entry.getTime();
                ByteArrayOutputStream baos = new ByteArrayOutputStream();
                IoUtil.pipe(in.getInputStream(entry), baos, buf);
                struct.data = baos.toByteArray();
                if (proc.process(struct)) {
                    if (entries.add(struct.name)) {
                        entry = new JarEntry(struct.name);
                        entry.setTime(struct.time);
                        entry.setCompressedSize(-1);
                        out.putNextEntry(entry);
                        out.write(struct.data);
                    } else if (struct.name.endsWith("/")) {
                        // TODO(chrisn): log
                    } else {
                        if(warnOnDuplicateClass) {
                            System.err.println("In " + from.getAbsolutePath() + ", found duplicate files with name: " + struct.name + ", ignoring due to specified option");
                        } else {
                            throw new DuplicateJarEntryException(from.getAbsolutePath(), struct.name);
                        }
                    }
                }
            }

        }
        finally {
            in.close();
            out.close();
        }

         // delete the empty directories
        IoUtil.copyZipWithoutEmptyDirectories(tmpTo, to);
        tmpTo.delete();

    }
}
