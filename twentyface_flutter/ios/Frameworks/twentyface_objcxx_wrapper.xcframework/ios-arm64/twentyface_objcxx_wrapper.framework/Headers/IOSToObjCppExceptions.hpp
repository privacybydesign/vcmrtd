extern NSErrorDomain const TwentyfaceErrorDomain;
typedef NS_ERROR_ENUM(TwentyfaceErrorDomain, TwentyfaceException) {
	PoseException = 2001,
	ScoreException = 2002,
	PositionException = 2003,
	ExposureException = 2004,
	SharpnessException = 2005,
	SizeException = 2006,
	DatabaseOpenException = 2007,
	LicenseException = 2008,
	DatabaseEntryNotFoundException = 2009,
	QualityException = 2010,
	InvalidConfigurationException = 2011,
	BiometricInvalidException = 2012,
	TooManyFacesFoundException = 2013,
	LoadModelsException = 2014,
	DatabaseExecutionException = 2015,
	VideoStreamException = 2016,
	NoMatchException = 2017,
	ImageReadException = 2018,
	NoFaceFoundException = 2019,
	SimilarFaceEnrolledException = 2020,
	TwentyFaceException = 2021,
	EndOfSupportException = 2022,
	EndOfSupportNearingException = 2023,
	stdexception = 3000,
	unknownexception = 3001
};

#define CATCH_AND_SET_EXCEPTION \
catch (const twentyface::PoseException& e) { \
	NSString *description = [NSString stringWithCString:std::string(e.what()).c_str() encoding:NSUTF8StringEncoding]; \
	NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(description, nil) }; \
	int errorCode = 2001; \
	*errorPtr = [NSError errorWithDomain:TwentyfaceErrorDomain code:errorCode userInfo:userInfo]; \
	NSLog(@"Exception in the 20facesdk: %@", description); \
} \
catch (const twentyface::ScoreException& e) { \
	NSString *description = [NSString stringWithCString:std::string(e.what()).c_str() encoding:NSUTF8StringEncoding]; \
	NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(description, nil) }; \
	int errorCode = 2002; \
	*errorPtr = [NSError errorWithDomain:TwentyfaceErrorDomain code:errorCode userInfo:userInfo]; \
	NSLog(@"Exception in the 20facesdk: %@", description); \
} \
catch (const twentyface::PositionException& e) { \
	NSString *description = [NSString stringWithCString:std::string(e.what()).c_str() encoding:NSUTF8StringEncoding]; \
	NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(description, nil) }; \
	int errorCode = 2003; \
	*errorPtr = [NSError errorWithDomain:TwentyfaceErrorDomain code:errorCode userInfo:userInfo]; \
	NSLog(@"Exception in the 20facesdk: %@", description); \
} \
catch (const twentyface::ExposureException& e) { \
	NSString *description = [NSString stringWithCString:std::string(e.what()).c_str() encoding:NSUTF8StringEncoding]; \
	NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(description, nil) }; \
	int errorCode = 2004; \
	*errorPtr = [NSError errorWithDomain:TwentyfaceErrorDomain code:errorCode userInfo:userInfo]; \
	NSLog(@"Exception in the 20facesdk: %@", description); \
} \
catch (const twentyface::SharpnessException& e) { \
	NSString *description = [NSString stringWithCString:std::string(e.what()).c_str() encoding:NSUTF8StringEncoding]; \
	NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(description, nil) }; \
	int errorCode = 2005; \
	*errorPtr = [NSError errorWithDomain:TwentyfaceErrorDomain code:errorCode userInfo:userInfo]; \
	NSLog(@"Exception in the 20facesdk: %@", description); \
} \
catch (const twentyface::SizeException& e) { \
	NSString *description = [NSString stringWithCString:std::string(e.what()).c_str() encoding:NSUTF8StringEncoding]; \
	NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(description, nil) }; \
	int errorCode = 2006; \
	*errorPtr = [NSError errorWithDomain:TwentyfaceErrorDomain code:errorCode userInfo:userInfo]; \
	NSLog(@"Exception in the 20facesdk: %@", description); \
} \
catch (const twentyface::DatabaseOpenException& e) { \
	NSString *description = [NSString stringWithCString:std::string(e.what()).c_str() encoding:NSUTF8StringEncoding]; \
	NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(description, nil) }; \
	int errorCode = 2007; \
	*errorPtr = [NSError errorWithDomain:TwentyfaceErrorDomain code:errorCode userInfo:userInfo]; \
	NSLog(@"Exception in the 20facesdk: %@", description); \
} \
catch (const twentyface::LicenseException& e) { \
	NSString *description = [NSString stringWithCString:std::string(e.what()).c_str() encoding:NSUTF8StringEncoding]; \
	NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(description, nil) }; \
	int errorCode = 2008; \
	*errorPtr = [NSError errorWithDomain:TwentyfaceErrorDomain code:errorCode userInfo:userInfo]; \
	NSLog(@"Exception in the 20facesdk: %@", description); \
} \
catch (const twentyface::DatabaseEntryNotFoundException& e) { \
	NSString *description = [NSString stringWithCString:std::string(e.what()).c_str() encoding:NSUTF8StringEncoding]; \
	NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(description, nil) }; \
	int errorCode = 2009; \
	*errorPtr = [NSError errorWithDomain:TwentyfaceErrorDomain code:errorCode userInfo:userInfo]; \
	NSLog(@"Exception in the 20facesdk: %@", description); \
} \
catch (const twentyface::QualityException& e) { \
	NSString *description = [NSString stringWithCString:std::string(e.what()).c_str() encoding:NSUTF8StringEncoding]; \
	NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(description, nil) }; \
	int errorCode = 2010; \
	*errorPtr = [NSError errorWithDomain:TwentyfaceErrorDomain code:errorCode userInfo:userInfo]; \
	NSLog(@"Exception in the 20facesdk: %@", description); \
} \
catch (const twentyface::InvalidConfigurationException& e) { \
	NSString *description = [NSString stringWithCString:std::string(e.what()).c_str() encoding:NSUTF8StringEncoding]; \
	NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(description, nil) }; \
	int errorCode = 2011; \
	*errorPtr = [NSError errorWithDomain:TwentyfaceErrorDomain code:errorCode userInfo:userInfo]; \
	NSLog(@"Exception in the 20facesdk: %@", description); \
} \
catch (const twentyface::BiometricInvalidException& e) { \
	NSString *description = [NSString stringWithCString:std::string(e.what()).c_str() encoding:NSUTF8StringEncoding]; \
	NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(description, nil) }; \
	int errorCode = 2012; \
	*errorPtr = [NSError errorWithDomain:TwentyfaceErrorDomain code:errorCode userInfo:userInfo]; \
	NSLog(@"Exception in the 20facesdk: %@", description); \
} \
catch (const twentyface::TooManyFacesFoundException& e) { \
	NSString *description = [NSString stringWithCString:std::string(e.what()).c_str() encoding:NSUTF8StringEncoding]; \
	NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(description, nil) }; \
	int errorCode = 2013; \
	*errorPtr = [NSError errorWithDomain:TwentyfaceErrorDomain code:errorCode userInfo:userInfo]; \
	NSLog(@"Exception in the 20facesdk: %@", description); \
} \
catch (const twentyface::LoadModelsException& e) { \
	NSString *description = [NSString stringWithCString:std::string(e.what()).c_str() encoding:NSUTF8StringEncoding]; \
	NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(description, nil) }; \
	int errorCode = 2014; \
	*errorPtr = [NSError errorWithDomain:TwentyfaceErrorDomain code:errorCode userInfo:userInfo]; \
	NSLog(@"Exception in the 20facesdk: %@", description); \
} \
catch (const twentyface::DatabaseExecutionException& e) { \
	NSString *description = [NSString stringWithCString:std::string(e.what()).c_str() encoding:NSUTF8StringEncoding]; \
	NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(description, nil) }; \
	int errorCode = 2015; \
	*errorPtr = [NSError errorWithDomain:TwentyfaceErrorDomain code:errorCode userInfo:userInfo]; \
	NSLog(@"Exception in the 20facesdk: %@", description); \
} \
catch (const twentyface::VideoStreamException& e) { \
	NSString *description = [NSString stringWithCString:std::string(e.what()).c_str() encoding:NSUTF8StringEncoding]; \
	NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(description, nil) }; \
	int errorCode = 2016; \
	*errorPtr = [NSError errorWithDomain:TwentyfaceErrorDomain code:errorCode userInfo:userInfo]; \
	NSLog(@"Exception in the 20facesdk: %@", description); \
} \
catch (const twentyface::NoMatchException& e) { \
	NSString *description = [NSString stringWithCString:std::string(e.what()).c_str() encoding:NSUTF8StringEncoding]; \
	NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(description, nil) }; \
	int errorCode = 2017; \
	*errorPtr = [NSError errorWithDomain:TwentyfaceErrorDomain code:errorCode userInfo:userInfo]; \
	NSLog(@"Exception in the 20facesdk: %@", description); \
} \
catch (const twentyface::ImageReadException& e) { \
	NSString *description = [NSString stringWithCString:std::string(e.what()).c_str() encoding:NSUTF8StringEncoding]; \
	NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(description, nil) }; \
	int errorCode = 2018; \
	*errorPtr = [NSError errorWithDomain:TwentyfaceErrorDomain code:errorCode userInfo:userInfo]; \
	NSLog(@"Exception in the 20facesdk: %@", description); \
} \
catch (const twentyface::NoFaceFoundException& e) { \
	NSString *description = [NSString stringWithCString:std::string(e.what()).c_str() encoding:NSUTF8StringEncoding]; \
	NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(description, nil) }; \
	int errorCode = 2019; \
	*errorPtr = [NSError errorWithDomain:TwentyfaceErrorDomain code:errorCode userInfo:userInfo]; \
	NSLog(@"Exception in the 20facesdk: %@", description); \
} \
catch (const twentyface::SimilarFaceEnrolledException& e) { \
	NSString *description = [NSString stringWithCString:std::string(e.what()).c_str() encoding:NSUTF8StringEncoding]; \
	NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(description, nil) }; \
	int errorCode = 2020; \
	*errorPtr = [NSError errorWithDomain:TwentyfaceErrorDomain code:errorCode userInfo:userInfo]; \
	NSLog(@"Exception in the 20facesdk: %@", description); \
} \
catch (const twentyface::TwentyFaceException& e) { \
	NSString *description = [NSString stringWithCString:std::string(e.what()).c_str() encoding:NSUTF8StringEncoding]; \
	NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(description, nil) }; \
	int errorCode = 2021; \
	*errorPtr = [NSError errorWithDomain:TwentyfaceErrorDomain code:errorCode userInfo:userInfo]; \
	NSLog(@"Exception in the 20facesdk: %@", description); \
} \
catch (const twentyface::EndOfSupportException& e) { \
	NSString *description = [NSString stringWithCString:std::string(e.what()).c_str() encoding:NSUTF8StringEncoding]; \
	NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(description, nil) }; \
	int errorCode = 2022; \
	*errorPtr = [NSError errorWithDomain:TwentyfaceErrorDomain code:errorCode userInfo:userInfo]; \
	NSLog(@"Exception in the 20facesdk: %@", description); \
} \
catch (const twentyface::EndOfSupportNearingException& e) { \
	NSString *description = [NSString stringWithCString:std::string(e.what()).c_str() encoding:NSUTF8StringEncoding]; \
	NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(description, nil) }; \
	int errorCode = 2023; \
	*errorPtr = [NSError errorWithDomain:TwentyfaceErrorDomain code:errorCode userInfo:userInfo]; \
	NSLog(@"Exception in the 20facesdk: %@", description); \
} \
catch (std::exception& e) { \
	NSString *description = [NSString stringWithCString:std::string(e.what()).c_str() encoding:NSUTF8StringEncoding]; \
	NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(description, nil) }; \
	int errorCode = 3000; \
	*errorPtr = [NSError errorWithDomain:TwentyfaceErrorDomain code:errorCode userInfo:userInfo]; \
	NSLog(@"Non 20face exception in the 20facesdk: %@", description); \
} \
catch (...) { \
	NSString *description = [NSString stringWithCString:std::string("An unknown exception occured in the twentyface library").c_str() encoding:NSUTF8StringEncoding]; \
	NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(description, nil) }; \
	int errorCode = 3001; \
	*errorPtr = [NSError errorWithDomain:TwentyfaceErrorDomain code:errorCode userInfo:userInfo]; \
	NSLog(@"Non 20face exception in the 20facesdk: %@", description); \
}