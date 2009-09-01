#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h> 
#include <Cocoa/Cocoa.h>
#include "logging.h"

#undef SRC_MODULE
#define SRC_MODULE "spot2spot"

/* -----------------------------------------------------------------------------
 Step 1
 Set the UTI types the importer supports
 
 Modify the CFBundleDocumentTypes entry in Info.plist to contain
 an array of Uniform Type Identifiers (UTI) for the LSItemContentTypes 
 that your importer can handle
 
 ----------------------------------------------------------------------------- */

/* -----------------------------------------------------------------------------
 Step 2 
 Implement the GetMetadataForFile function
 
 Implement the GetMetadataForFile function below to scrape the relevant
 metadata from your document and return it as a CFDictionary using standard keys
 (defined in MDItem.h) whenever possible.
 ----------------------------------------------------------------------------- */

/* -----------------------------------------------------------------------------
 Step 3 (optional) 
 If you have defined new attributes, update the schema.xml file
 
 Edit the schema.xml file to include the metadata keys that your importer returns.
 Add them to the <allattrs> and <displayattrs> elements.
 
 Add any custom types that your importer requires to the <attributes> element
 
 <attribute name="com_mycompany_metadatakey" type="CFString" multivalued="true"/>
 
 ----------------------------------------------------------------------------- */



/* -----------------------------------------------------------------------------
 Get metadata attributes from file
 
 This function's job is to extract useful information your file format supports
 and return it as a dictionary
 ----------------------------------------------------------------------------- */

Boolean GetMetadataForFile(void* thisInterface, 
													 CFMutableDictionaryRef attributes, 
													 CFStringRef contentTypeUTI,
													 CFStringRef path);

Boolean GetMetadataForFile(void* thisInterface, 
													 CFMutableDictionaryRef attributes, 
													 CFStringRef contentTypeUTI,
													 CFStringRef path)
{
#if DEBUG
  Log_notice(@"import %@", path);
#endif
  NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:(NSString *)path];
  NSMutableDictionary *md = (NSMutableDictionary *)attributes;
  [md addEntriesFromDictionary:d];
  return TRUE;
}
