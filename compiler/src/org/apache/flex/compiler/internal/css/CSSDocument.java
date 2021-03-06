/*
 *
 *  Licensed to the Apache Software Foundation (ASF) under one or more
 *  contributor license agreements.  See the NOTICE file distributed with
 *  this work for additional information regarding copyright ownership.
 *  The ASF licenses this file to You under the Apache License, Version 2.0
 *  (the "License"); you may not use this file except in compliance with
 *  the License.  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 *
 */

package org.apache.flex.compiler.internal.css;

import java.util.Collection;
import java.util.List;

import org.antlr.runtime.CharStream;
import org.antlr.runtime.CommonTokenStream;
import org.antlr.runtime.RecognitionException;
import org.antlr.runtime.TokenStream;
import org.antlr.runtime.tree.CommonTree;
import org.antlr.runtime.tree.CommonTreeNodeStream;

import org.apache.flex.compiler.css.ICSSDocument;
import org.apache.flex.compiler.css.ICSSFontFace;
import org.apache.flex.compiler.css.ICSSNamespaceDefinition;
import org.apache.flex.compiler.css.ICSSRule;
import org.apache.flex.compiler.internal.css.CSSLexer;
import org.apache.flex.compiler.internal.css.CSSParser;
import org.apache.flex.compiler.internal.css.CSSTree;
import org.apache.flex.compiler.problems.ICompilerProblem;
import org.apache.flex.compiler.problems.UnexpectedExceptionProblem;
import com.google.common.base.Function;
import com.google.common.base.Joiner;
import com.google.common.collect.ImmutableList;
import com.google.common.collect.ImmutableMap;
import com.google.common.collect.Maps;

/**
 * Implementation of a CSS model.
 */
public class CSSDocument extends CSSNodeBase implements ICSSDocument
{
    /** The short name for the default namespace is an empty string. */
    private static final String DEFAULT_NAMESPACE_SHORT_NAME = "";

    /**
     * Parse a CSS document into {@link ICSSDocument} model.
     * 
     * @param input ANTLR input stream. The {@code CharStream#getSourceName()}
     * must be implemented in order to make source location work.
     * @param problems Parsing problems will be aggregated in this collection.
     * @return CSS DOM object.
     */
    public static CSSDocument parse(final CharStream input, final Collection<ICompilerProblem> problems)
    {
        assert input != null : "CSS input can't be null";
        assert problems != null : "Problem collection can't be null";

        try
        {
            // parse and build tree
            final CSSLexer lexer = new CSSLexer(input);
            final CommonTokenStream tokens = new CommonTokenStream(lexer);
            final CSSParser parser = new CSSParser(tokens);
            final CSSParser.stylesheet_return stylesheet = parser.stylesheet();
            final CommonTree ast = (CommonTree)stylesheet.getTree();
            final CommonTreeNodeStream nodes = new CommonTreeNodeStream(ast);
            nodes.setTokenStream(tokens);

            // walk the tree and build definitions
            final CSSTree treeWalker = new CSSTree(nodes);
            treeWalker.stylesheet();

            problems.addAll(lexer.problems);
            problems.addAll(parser.problems);
            problems.addAll(treeWalker.problems);

            // definition models
            return treeWalker.model;
        }
        catch (RecognitionException e)
        {
            assert false : "RecognitionException must be collected as ICompilerProblem.";
            problems.add(new UnexpectedExceptionProblem(e));
            return null;
        }
    }

    /**
     * A function that computes the key of a {@code ICSSNamespaceDefinition} for
     * the lookup table of namespaces. The key of each namespace definition is
     * its prefix name. The default namespace prefix is an empty string.
     */
    private static final Function<CSSNamespaceDefinition, String> KEY_GENERATOR =
            new Function<CSSNamespaceDefinition, String>()
    {
        @Override
        public String apply(CSSNamespaceDefinition ns)
        {
            final String prefix = ns.getPrefix();
            if (prefix == null)
                return DEFAULT_NAMESPACE_SHORT_NAME;
            else
                return prefix;
        }
    };

    /**
     * Create a root CSS definition.
     * 
     * @param rules CSS rules
     * @param namespaces {@code @namespace} statements
     * @param fontFaces {@code @font-face} statements
     * @param tree root of the AST
     */
    protected CSSDocument(final List<CSSRule> rules,
                          final List<CSSNamespaceDefinition> namespaces,
                          final List<CSSFontFace> fontFaces,
                          final CommonTree tree,
                          final TokenStream tokenStream)
    {
        super(tree, tokenStream, CSSModelTreeType.DOCUMENT);

        assert rules != null : "Rules can't be null.";
        assert namespaces != null : "Namespace definitions can't be null";
        assert fontFaces != null : "Font face definitions can't be null";

        this.rules = new ImmutableList.Builder<ICSSRule>().addAll(rules).build();
        this.namespaces = new ImmutableList.Builder<ICSSNamespaceDefinition>().addAll(namespaces).build();
        this.fontFaces = new ImmutableList.Builder<ICSSFontFace>().addAll(fontFaces).build();
        this.namespacesLookup = Maps.uniqueIndex(namespaces, KEY_GENERATOR);

        // setup tree
        children.add(new CSSTypedNode(CSSModelTreeType.NAMESPACE_LIST, this.namespaces));
        children.add(new CSSTypedNode(CSSModelTreeType.FONT_FACE_LIST, this.fontFaces));
        children.add(new CSSTypedNode(CSSModelTreeType.RULE_LIST, this.rules));
    }

    private final ImmutableList<ICSSRule> rules;
    private final ImmutableList<ICSSNamespaceDefinition> namespaces;
    private final ImmutableList<ICSSFontFace> fontFaces;
    private final ImmutableMap<String, CSSNamespaceDefinition> namespacesLookup;

    @Override
    public ImmutableList<ICSSRule> getRules()
    {
        return rules;
    }

    @Override
    public ImmutableList<ICSSNamespaceDefinition> getAtNamespaces()
    {
        return namespaces;
    }

    @Override
    public String toString()
    {
        return Joiner.on("\n").join(
                Joiner.on("\n").join(namespaces),
                Joiner.on("\n").join(fontFaces),
                Joiner.on("\n").join(rules));
    }

    @Override
    public ImmutableList<ICSSFontFace> getFontFaces()
    {
        return fontFaces;
    }

    @Override
    public ICSSNamespaceDefinition getNamespaceDefinition(String prefix)
    {
        return namespacesLookup.get(prefix);
    }

    @Override
    public ICSSNamespaceDefinition getDefaultNamespaceDefinition()
    {
        return namespacesLookup.get(DEFAULT_NAMESPACE_SHORT_NAME);
    }
}
