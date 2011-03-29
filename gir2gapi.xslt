<?xml version="1.0" encoding="UTF-8"?>

<!--
//
// .xslt
//
// This stylesheet converts gir to gapi format
//
//
//
//
// Author:
//   Andreia Gaita (shana@spoiledcat.net)
//
// Permission is hereby granted, free of charge, to any person obtaining
// a copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to
// the following conditions:
// 
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
// LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
// OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
// WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
-->

<xsl:stylesheet version="1.0" 
xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
xmlns:exsl="http://exslt.org/common"
xmlns:gir="http://www.gtk.org/introspection/core/1.0"
xmlns:c="http://www.gtk.org/introspection/c/1.0"
xmlns:glib="http://www.gtk.org/introspection/glib/1.0"
exclude-result-prefixes="xsl exsl gir c glib"

>
	<xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes"/>
	<xsl:strip-space elements="*" />

	<!--- maps svg names into xaml names -->
	<xsl:variable name="mappings">
		<mappings>
			<mapping from="default" to="_default"/>
			<mapping from="object" to="_object"/>
			<mapping from="GObjectObject" to="GObject"/>
		</mappings>
	</xsl:variable>

	<xsl:variable name="consttypes">
		<types>
			<type name="char*" />
			<type name="gchar*" />
			<type name="gfilename*" />
		</types>
	</xsl:variable>

	<xsl:variable name="typemappings">
		<mappings>
			<mapping from="gchararray" to="gchar*"/>
		</mappings>
	</xsl:variable>
	<!-- START HERE -->
	
	<xsl:template match="/">
		<xsl:apply-templates />
	</xsl:template>

	<xsl:template match="gir:repository">
		<api>
			<xsl:apply-templates select="gir:namespace"/>
		</api>
	</xsl:template>	

	<xsl:template match="gir:namespace">
		<xsl:variable name="split1"><xsl:value-of select="substring-after(@shared-library, 'lib')" /></xsl:variable>
		<xsl:variable name="library"><xsl:value-of select="substring-before($split1, '.so')" /></xsl:variable>
		<namespace name="{@name}" library="{$library}">
			<xsl:apply-templates />
		</namespace>
	</xsl:template>	


	<xsl:template match="gir:class">
		<xsl:variable name="parent">
			<xsl:call-template name="validate">
				<xsl:with-param name="name">
					<xsl:choose><xsl:when test="contains(@parent, '.')">
						<xsl:call-template name="capitalize">
							<xsl:with-param name="string" select="@parent" />
							<xsl:with-param name="sep">.</xsl:with-param>
						</xsl:call-template>
					</xsl:when><xsl:otherwise>
					<xsl:value-of select="../@name"/><xsl:value-of select="@parent"/>
					</xsl:otherwise></xsl:choose>
				</xsl:with-param>
			</xsl:call-template>
		</xsl:variable>

		<xsl:variable name="type"><xsl:call-template name="map-type"><xsl:with-param name="type" select="@c:type"/></xsl:call-template></xsl:variable>
		<object name="{@name}" cname="{$type}" parent="{$parent}">
		      <method name="GetType" cname="{@glib:get-type}" shared="true">
		        <return-type type="GType" />
		      </method>

			<xsl:apply-templates />
		</object>
	</xsl:template>	

	<xsl:template match="gir:method">
		<xsl:variable name="name">
			<xsl:call-template name="capitalize">
				<xsl:with-param name="string" select="@name" />
			</xsl:call-template>
		</xsl:variable>

		<method name="{$name}" cname="{@c:identifier}">
			<xsl:variable name="rtypemap"><xsl:call-template name="map-type"><xsl:with-param name="type" select="gir:return-value/gir:type/@c:type"/></xsl:call-template></xsl:variable>
			<xsl:variable name="rtype">
				<xsl:choose>
				<xsl:when test="../gir:enumeration[@name=$rtypemap]">
					<xsl:text>int</xsl:text>
				</xsl:when>
				<xsl:when test="gir:return-value[@transfer-ownership='none'] and exsl:node-set($consttypes)/types/type[@name=$rtypemap]">
					<xsl:text>const-</xsl:text><xsl:value-of select="$rtypemap"/>
				</xsl:when>
				<xsl:otherwise>
					<xsl:value-of select="$rtypemap"/>
				</xsl:otherwise></xsl:choose>
			</xsl:variable>

			<return-type type="{$rtype}" />

			<xsl:if test="gir:parameters">
				<parameters>
				<xsl:for-each select="gir:parameters/gir:parameter">
					<xsl:variable name="pname"><xsl:call-template name="validate"><xsl:with-param name="name" select="@name"/></xsl:call-template></xsl:variable>
					<xsl:variable name="ptypemap"><xsl:call-template name="map-type"><xsl:with-param name="type" select="gir:type/@c:type"/></xsl:call-template></xsl:variable>
					<!-- stupid hack to replace enums with int because gapi is stupid and doesn't register their types -->
					<xsl:variable name="ptype">
						<xsl:choose><xsl:when test="../gir:namespace/gir:enumeration[@name=gir:type/@c:type]">
							<xsl:text>int</xsl:text>
						</xsl:when><xsl:otherwise>
							<xsl:value-of select="$ptypemap"/>
						</xsl:otherwise></xsl:choose>
					</xsl:variable>
					<parameter name="{$pname}" type="{$ptype}" />
				</xsl:for-each>
				</parameters>
			</xsl:if>
		</method>
	</xsl:template>	

	<xsl:template match="gir:constructor">
		<constructor cname="{@c:identifier}">
			<xsl:if test="gir:parameters">
				<parameters>
				<xsl:for-each select="gir:parameters/gir:parameter">
					<xsl:variable name="name"><xsl:call-template name="validate"><xsl:with-param name="name" select="@name"/></xsl:call-template></xsl:variable>
					<xsl:variable name="ptypemap"><xsl:call-template name="map-type"><xsl:with-param name="type" select="gir:type/@c:type"/></xsl:call-template></xsl:variable>
					<!-- stupid hack to replace enums with int because gapi is stupid and doesn't register their types -->
					<xsl:variable name="ptype">
						<xsl:choose><xsl:when test="../../../gir:namespace/gir:enumeration[@c:type=gir:type/@c:type]">
							<xsl:text>int</xsl:text>
						</xsl:when><xsl:otherwise>
							<xsl:value-of select="$ptypemap"/>
						</xsl:otherwise></xsl:choose>
					</xsl:variable>
					<parameter type="{$ptype}" name="{$name}" />
				</xsl:for-each>
				</parameters>
			</xsl:if>
		</constructor>
	</xsl:template>	

	<xsl:template match="gir:virtual-method">
		<xsl:variable name="name">
			<xsl:call-template name="capitalize">
				<xsl:with-param name="string" select="@name" />
			</xsl:call-template>
		</xsl:variable>

		<xsl:if test="not(../gir:method[@name = current()/@name])">
			<xsl:variable name="rtypemap"><xsl:call-template name="map-type"><xsl:with-param name="type" select="gir:return-value/gir:type/@c:type"/></xsl:call-template></xsl:variable>
			<signal name="{$name}" cname="{@name}">
				<xsl:variable name="t" select="$rtypemap"/>
				<xsl:variable name="rtype">
					<xsl:choose>
					<xsl:when test="//*/gir:enumeration[@c:type=$t]">
						<xsl:text>int</xsl:text>
					</xsl:when>
					<xsl:when test="gir:return-value[@transfer-ownership='none'] and exsl:node-set($consttypes)/types/type[@name=$rtypemap]">
						<xsl:text>const-</xsl:text><xsl:value-of select="$rtypemap"/>
					</xsl:when>
					<xsl:otherwise>
						<xsl:value-of select="$rtypemap"/>
					</xsl:otherwise>
					</xsl:choose>
				</xsl:variable>

				<return-type type="{$rtype}" />

				<parameters>
					<xsl:variable name="prtypemap"><xsl:call-template name="map-type"><xsl:with-param name="type" select="../@c:type"/></xsl:call-template></xsl:variable>
					<parameter
						name="{translate(../@name,'ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz')}" 
						type="{$prtypemap}*" />
					<xsl:for-each select="gir:parameters/gir:parameter">
						<xsl:variable name="ptypemap"><xsl:call-template name="map-type"><xsl:with-param name="type" select="gir:type/@c:type"/></xsl:call-template></xsl:variable>
						<xsl:variable name="pname"><xsl:call-template name="validate"><xsl:with-param name="name" select="@name"/></xsl:call-template></xsl:variable>
						<!-- stupid hack to replace enums with int because gapi is stupid and doesn't register their types -->
						<xsl:variable name="ptype">
							<xsl:choose>
							<xsl:when test="../../../gir:namespace/gir:enumeration[@c:type=gir:type/@c:type]">
								<xsl:text>int</xsl:text>
							</xsl:when>
							<xsl:when test="@transfer-ownership='none' and exsl:node-set($consttypes)/types/type[@name=$ptypemap]">
								<xsl:text>const-</xsl:text><xsl:value-of select="$ptypemap"/>
							</xsl:when>
							<xsl:otherwise>
								<xsl:value-of select="$ptypemap"/>
							</xsl:otherwise>
							</xsl:choose>
						</xsl:variable>
						<parameter name="{$pname}" type="{$ptype}" />
					</xsl:for-each>
				</parameters>
			</signal>
		</xsl:if>
	</xsl:template>	

	<xsl:template match="glib:signal">
		<xsl:variable name="name">
			<xsl:call-template name="capitalize">
				<xsl:with-param name="string" select="@name" />
				<xsl:with-param name="sep"><xsl:text>-</xsl:text></xsl:with-param>
			</xsl:call-template>
		</xsl:variable>

		<xsl:if test="not(../gir:method[@name = translate(current()/@name,'-','_')]) and not(../gir:virtual-method[@name = translate(current()/@name,'-','_')])">
			<xsl:variable name="rtypemap"><xsl:call-template name="map-type"><xsl:with-param name="type" select="gir:return-value/gir:type/@c:type"/></xsl:call-template></xsl:variable>
			<signal name="{$name}" cname="{@name}">
				<xsl:variable name="t" select="$rtypemap"/>
				<xsl:variable name="rtype">
					<xsl:choose>
					<xsl:when test="//*/gir:enumeration[@c:type=$t]">
						<xsl:text>int</xsl:text>
					</xsl:when>
					<xsl:when test="gir:return-value[@transfer-ownership='none'] and exsl:node-set($consttypes)/types/type[@name=$rtypemap]">
						<xsl:text>const-</xsl:text><xsl:value-of select="$rtypemap"/>
					</xsl:when>
					<xsl:otherwise>
						<xsl:value-of select="$rtypemap"/>
					</xsl:otherwise>
					</xsl:choose>
				</xsl:variable>

				<return-type type="{$rtype}" />

				<parameters>

					<xsl:variable name="prtypemap"><xsl:call-template name="map-type"><xsl:with-param name="type" select="../@c:type"/></xsl:call-template></xsl:variable>
					<parameter
						name="{translate(../@name,'ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz')}"
						type="{$prtypemap}*" />

					<xsl:for-each select="gir:parameters/gir:parameter">
						<xsl:variable name="ptypemap"><xsl:call-template name="map-type"><xsl:with-param name="type" select="gir:type/@c:type"/></xsl:call-template></xsl:variable>
						<xsl:variable name="pname"><xsl:call-template name="validate"><xsl:with-param name="name" select="@name"/></xsl:call-template></xsl:variable>
						<!-- stupid hack to replace enums with int because gapi is stupid and doesn't register their types -->
						<xsl:variable name="ptype">
							<xsl:choose>
							<xsl:when test="../../../gir:namespace/gir:enumeration[@c:type=gir:type/@c:type]">
								<xsl:text>int</xsl:text>
							</xsl:when>
							<xsl:when test="@transfer-ownership='none' and exsl:node-set($consttypes)/types/type[@name=$ptypemap]">
								<xsl:text>const-</xsl:text><xsl:value-of select="$ptypemap"/>
							</xsl:when>
							<xsl:otherwise>
								<xsl:value-of select="$ptypemap"/>
							</xsl:otherwise>
							</xsl:choose>
						</xsl:variable>
						<parameter name="{$pname}" type="{$ptype}" />
					</xsl:for-each>
				</parameters>
			</signal>
		</xsl:if>
	</xsl:template>	

	<xsl:template match="gir:enumeration">
		<enum name="{@name}" cname="{@c:type}">
			<xsl:for-each select="gir:member">
				<xsl:sort select="@value" />
				<xsl:variable name="ename"><xsl:call-template name="capitalize"><xsl:with-param name="string" select="@name"/></xsl:call-template></xsl:variable>
				<xsl:variable name="name"><xsl:call-template name="validate"><xsl:with-param name="name" select="$ename"/></xsl:call-template></xsl:variable>
				<member cname="{@c:identifier}" name="{$name}" />
			</xsl:for-each>
		</enum>
	</xsl:template>	

	<xsl:template match="gir:*">
	</xsl:template>
	<xsl:template match="text()" mode="#all" />

	<xsl:template name="validate">
		<xsl:param name="name"/>
		<xsl:choose>
			<xsl:when test="not(exsl:node-set($mappings)/mappings/mapping[@from=$name])"><xsl:value-of select="$name" /></xsl:when>
			<xsl:otherwise><xsl:value-of select="exsl:node-set($mappings)/mappings/mapping[@from=$name]/@to" /></xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<xsl:template name="capitalize">
		<xsl:param name="string"/>
		<xsl:param name="sep">_</xsl:param>
		<xsl:value-of select="translate(substring($string,1,1),'abcdefghijklmnopqrstuvwxyz','ABCDEFGHIJKLMNOPQRSTUVWXYZ')"/>
		<xsl:choose><xsl:when test="contains($string,$sep)">
			<xsl:value-of select="substring-before(substring($string,2),$sep)"/>
		</xsl:when><xsl:otherwise>
			<xsl:value-of select="substring($string,2)"/>
		</xsl:otherwise></xsl:choose>
		<xsl:if test="contains($string,$sep)">
			<xsl:call-template name="capitalize">
				<xsl:with-param name="string" select="substring-after($string,$sep)"/>
				<xsl:with-param name="sep" select="$sep"/>
			</xsl:call-template>
		</xsl:if>
	</xsl:template>

	<xsl:template name="map-type">
		<xsl:param name="type" />
		<xsl:choose>
			<xsl:when test="exsl:node-set($typemappings)/mappings/mapping[@from=$type]"><xsl:value-of select="exsl:node-set($typemappings)/mappings/mapping[@from=$type]/@to" /></xsl:when>
			<xsl:otherwise><xsl:value-of select="$type" /></xsl:otherwise>
		</xsl:choose>
	</xsl:template>

</xsl:stylesheet>
