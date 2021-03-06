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

/**
 * This is a tree grammar for advanced CSS in Flex. It walks the AST generated 
 * by the CSS parser and builds CSS DOM objects.
 */
tree grammar CSSTree;

options 
{
    language = Java;
    tokenVocab = CSS;
    ASTLabelType = CommonTree;
}

@header 
{
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

import java.util.Map;
import java.util.HashMap;
import org.apache.flex.compiler.css.*;
import org.apache.flex.compiler.problems.CSSParserProblem;

}

@members 
{

/**
 * CSS DOM object.
 */
protected CSSDocument model;

/**
 * Every definition object needs the token stream to compute source location.
 */
private final TokenStream tokenStream = getTreeNodeStream().getTokenStream();

/**
 * Tree walker problems.
 */
protected List<CSSParserProblem> problems = new ArrayList<CSSParserProblem>();

/**
 * Collect problems.
 */
@Override
public void displayRecognitionError(String[] tokenNames, RecognitionException e)
{
    problems.add(CSSParserProblem.create(this, tokenNames, e));
}
}

stylesheet
scope 
{
    // namespace declarations are buffered in this map
    List<CSSNamespaceDefinition> namespaces;
    // ruleset definitions are buffered in this list
    List<CSSRule> rules;
    // font-face declarations are buffered in this list
    List<CSSFontFace> fontFaces;
}
@init 
{
    $stylesheet::rules = new ArrayList<CSSRule>();
    $stylesheet::namespaces = new ArrayList<CSSNamespaceDefinition>();
    $stylesheet::fontFaces = new ArrayList<CSSFontFace>();
}
@after 
{
    model = new CSSDocument($stylesheet::rules, 
                            $stylesheet::namespaces, 
                            $stylesheet::fontFaces,
                            $start,
                            tokenStream);
}
    :   ( namespaceStatement | fontFace | mediaQuery | ruleset )*
    ;

namespaceStatement
@after        
{ 
    final CSSNamespaceDefinition ns = new CSSNamespaceDefinition(
            $id.text, $uri.text, $start, tokenStream);
    $stylesheet::namespaces.add(ns); 
}
    :   ^(AT_NAMESPACE id=ID? uri=STRING)
    ;
  
mediaQuery
scope 
{ 
    // media query condition clauses are buffered in this list
    List<CSSMediaQueryCondition> conditions 
}
@init 
{ 
    $mediaQuery::conditions = new ArrayList<CSSMediaQueryCondition>(); 
}
    :   ^(AT_MEDIA medium ruleset*)
    ;
  
medium 
    :   ^(I_MEDIUM_CONDITIONS mediumCondition*)
    ;
  
mediumCondition
@after 
{ 
    $mediaQuery::conditions.add(new CSSMediaQueryCondition($start, tokenStream)); 
} 
    :   ID | ARGUMENTS
    ;
    
fontFace
@after
{
    final CSSFontFace fontFace = new CSSFontFace($d.properties, $start, tokenStream);
    $stylesheet::fontFaces.add(fontFace);
}
    :   ^(AT_FONT_FACE d=declarationsBlock)
    ;
  
ruleset
scope 
{
    // list of subject selectors
    List<CSSSelector> subjects
}
@init 
{
    $ruleset::subjects = new ArrayList<CSSSelector>();
}
@after 
{
    final List<CSSMediaQueryCondition> mediaQueryConditions;
    if ($mediaQuery.isEmpty())
        mediaQueryConditions = null;
    else
        mediaQueryConditions = $mediaQuery::conditions;
    
    final CSSRule cssRule = new CSSRule(
            mediaQueryConditions,
            $ruleset::subjects,
            $d.properties, 
            $start, 
            tokenStream);
    $stylesheet::rules.add(cssRule);
}
    :   ^(I_RULE selectorGroup d=declarationsBlock)
    ;

selectorGroup
    :  ^(I_SELECTOR_GROUP compoundSelector+)
    ;    

compoundSelector
@init
{
    final Stack<CSSSelector> simpleSelectorStack = new Stack<CSSSelector>();
}
@after
{
    $ruleset::subjects.add(simpleSelectorStack.peek());
}
    :   ^(I_SELECTOR simpleSelector[simpleSelectorStack]+)   
    ;
    
simpleSelector [Stack<CSSSelector> simpleSelectorStack]
scope
{
    String namespace;
    String element;
    List<CSSSelectorCondition> conditions;
}
@init
{
    $simpleSelector::conditions = new ArrayList<CSSSelectorCondition>();
    final CSSCombinator combinator ;
    if (simpleSelectorStack.isEmpty())
        combinator = null;
    else                    
        combinator = new CSSCombinator(simpleSelectorStack.peek(), CombinatorType.DESCENDANT);
}
@after
{
    final CSSSelector simpleSelector = new CSSSelector(
        combinator,
        $simpleSelector::element,
        $simpleSelector::namespace,
        $simpleSelector::conditions, 
        $start, 
        tokenStream);
    simpleSelectorStack.push(simpleSelector);
}
    :   ^(I_SIMPLE_SELECTOR simpleSelectorFraction+)
    ;    
    
simpleSelectorFraction
    :   elementSelector
    |   conditionSelector 
    ;
   
conditionSelector
@init
{
    ConditionType type = null;
    String name = null;
}
@after
{
    $simpleSelector::conditions.add(
        new CSSSelectorCondition(name, type, $start, tokenStream));
}
    :   ^(DOT c=ID)   { type = ConditionType.CLASS; name = $c.text; }  
    |   HASH_WORD   { type = ConditionType.ID; name = $HASH_WORD.text.substring(1); }
    |   ^(COLON s=ID) { type = ConditionType.PSEUDO; name = $s.text; } 
    ;
  
elementSelector
    :   ^(PIPE ns=ID e1=ID)  
        { $simpleSelector::element = $e1.text; 
          $simpleSelector::namespace = $ns.text; }
    |   e2=ID             
        { $simpleSelector::element = $e2.text; }
    |   STAR           
        { $simpleSelector::element = $STAR.text; }
    ;
    
declarationsBlock returns [List<CSSProperty> properties]
@init 
{
    $properties = new ArrayList<CSSProperty>();
}
    :   ^(I_DECL (declaration 
         { 
             if ($declaration.property != null)
                 $properties.add($declaration.property); 
         }
         )*)
    ;

declaration returns [CSSProperty property]
@after
{
    if ($id.text != null && $v.propertyValue != null)
        $property = new CSSProperty($id.text, $v.propertyValue, $start, tokenStream);  
}
    :   ^(COLON id=ID v=value)
    ;
    
value returns [CSSPropertyValue propertyValue]
    :   ^( I_ARRAY 
                              { final List<CSSPropertyValue> array = new ArrayList<CSSPropertyValue>(); }
           ( s1=singleValue   { array.add($s1.propertyValue); } )+
        )                     { $propertyValue = new CSSArrayPropertyValue(array, $start, tokenStream); }
    |   s2=singleValue        { $propertyValue = $s2.propertyValue; }
    ;    
  
singleValue returns [CSSPropertyValue propertyValue]
    :   NUMBER_WITH_UNIT         
		{ $propertyValue = new CSSNumberPropertyValue($NUMBER_WITH_UNIT.text, $start, tokenStream); }
    |   HASH_WORD         
        { $propertyValue = new CSSColorPropertyValue($start, tokenStream); }
    |   ^(CLASS_REFERENCE cr=ARGUMENTS)
        { $propertyValue = new CSSFunctionCallPropertyValue($CLASS_REFERENCE.text, $cr.text, $start, tokenStream); }
    |   ^(PROPERTY_REFERENCE pr=ARGUMENTS)
        { $propertyValue = new CSSFunctionCallPropertyValue($PROPERTY_REFERENCE.text, $pr.text, $start, tokenStream); }
    |   ^(EMBED es=ARGUMENTS)
        { $propertyValue = new CSSFunctionCallPropertyValue($EMBED.text, $es.text, $start, tokenStream); }
    |   ^(URL url=ARGUMENTS)
        { $propertyValue = new CSSFunctionCallPropertyValue($URL.text, $url.text, $start, tokenStream); }
    |   ^(LOCAL l=ARGUMENTS)
        { $propertyValue = new CSSFunctionCallPropertyValue($LOCAL.text, $l.text, $start, tokenStream); }
    |   s=STRING   
        { $propertyValue = new CSSStringPropertyValue($s.text, $start, tokenStream); }                   
    |   ID
        { $propertyValue = CSSKeywordPropertyValue.create($start, tokenStream); } 
    ;
    
argumentList returns [List<String> labels, List<String> values]
@init 
{
    $labels = new ArrayList<String>(3);
    $values = new ArrayList<String>(3);
}
    :   argument[$labels, $values]+
    ;
    
argument [List<String> labels, List<String> values]
@after
{
    // Use null for argument without label.
    $labels.add($l.text);
    $values.add($v.text); 
}
    :   ^(EQUALS l=ID? v=STRING)
    ;
