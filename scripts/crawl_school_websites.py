#!/usr/bin/env python3
"""
Firecrawl School Website Crawler

This script crawls school websites comprehensively using Firecrawl to extract
structured information for AI processing. It includes extracurricular activities,
academic programs, facilities, admissions info, and more.

Usage:
    python scripts/crawl_school_websites.py --school-id 123
    python scripts/crawl_school_websites.py --website "https://school.com"
    python scripts/crawl_school_websites.py --all  # Process all schools
"""

import os
import sys
import json
import time
import argparse
import logging
from datetime import datetime
from typing import Dict, List, Optional, Any
import requests

# Add the Rails root to Python path to access environment
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

try:
    from firecrawl import FirecrawlApp
except ImportError:
    print("❌ Firecrawl package not found. Install with: pip install firecrawl-py")
    sys.exit(1)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('logs/school_website_crawling.log'),
        logging.StreamHandler()
    ]
)

class SchoolWebsiteCrawler:
    """Comprehensive school website crawler using Firecrawl"""
    
    def __init__(self, api_key: str):
        """Initialize the crawler with Firecrawl API key"""
        self.firecrawl = FirecrawlApp(api_key=api_key)
        self.stats = {
            'processed': 0,
            'successful': 0,
            'failed': 0,
            'start_time': datetime.now()
        }
        
        # Comprehensive JSON schema for school data extraction
        self.school_schema = {
            "type": "object",
            "properties": {
                "basic_info": {
                    "type": "object",
                    "properties": {
                        "school_name": {"type": "string"},
                        "school_type": {"type": "string"},
                        "founded_year": {"type": "string"},
                        "motto": {"type": "string"},
                        "mission_statement": {"type": "string"},
                        "vision_statement": {"type": "string"}
                    }
                },
                "academics": {
                    "type": "object", 
                    "properties": {
                        "programs_offered": {"type": "array", "items": {"type": "string"}},
                        "grade_levels": {"type": "string"},
                        "curriculum": {"type": "array", "items": {"type": "string"}},
                        "languages_taught": {"type": "array", "items": {"type": "string"}},
                        "special_programs": {"type": "array", "items": {"type": "string"}},
                        "academic_departments": {"type": "array", "items": {"type": "string"}},
                        "advanced_placement": {"type": "array", "items": {"type": "string"}},
                        "international_programs": {"type": "array", "items": {"type": "string"}}
                    }
                },
                "admissions": {
                    "type": "object",
                    "properties": {
                        "admission_requirements": {"type": "string"},
                        "application_deadlines": {"type": "string"},
                        "entrance_exams": {"type": "string"},
                        "age_requirements": {"type": "string"},
                        "documents_required": {"type": "array", "items": {"type": "string"}},
                        "admission_process": {"type": "string"},
                        "open_house_dates": {"type": "string"}
                    }
                },
                "extracurricular": {
                    "type": "object",
                    "properties": {
                        "sports_offered": {"type": "array", "items": {"type": "string"}},
                        "clubs_activities": {"type": "array", "items": {"type": "string"}},
                        "arts_programs": {"type": "array", "items": {"type": "string"}},
                        "music_programs": {"type": "array", "items": {"type": "string"}},
                        "drama_theater": {"type": "array", "items": {"type": "string"}},
                        "competitions": {"type": "array", "items": {"type": "string"}},
                        "student_government": {"type": "string"},
                        "community_service": {"type": "string"}
                    }
                },
                "facilities": {
                    "type": "object",
                    "properties": {
                        "campus_facilities": {"type": "array", "items": {"type": "string"}},
                        "laboratories": {"type": "array", "items": {"type": "string"}},
                        "sports_facilities": {"type": "array", "items": {"type": "string"}},
                        "technology": {"type": "array", "items": {"type": "string"}},
                        "library_resources": {"type": "string"},
                        "cafeteria_dining": {"type": "string"},
                        "medical_facilities": {"type": "string"},
                        "security_features": {"type": "array", "items": {"type": "string"}}
                    }
                },
                "fees_costs": {
                    "type": "object",
                    "properties": {
                        "tuition_fees": {"type": "string"},
                        "application_fee": {"type": "string"},
                        "enrollment_fee": {"type": "string"},
                        "additional_costs": {"type": "string"},
                        "scholarships": {"type": "string"},
                        "financial_aid": {"type": "string"},
                        "payment_terms": {"type": "string"},
                        "fee_structure_by_grade": {"type": "string"}
                    }
                },
                "contact_transport": {
                    "type": "object",
                    "properties": {
                        "school_hours": {"type": "string"},
                        "transport_options": {"type": "array", "items": {"type": "string"}},
                        "pickup_areas": {"type": "array", "items": {"type": "string"}},
                        "parking_information": {"type": "string"},
                        "contact_persons": {"type": "array", "items": {"type": "object"}},
                        "emergency_contacts": {"type": "string"}
                    }
                },
                "faculty_staff": {
                    "type": "object",
                    "properties": {
                        "teacher_student_ratio": {"type": "string"},
                        "faculty_qualifications": {"type": "string"},
                        "key_personnel": {"type": "array", "items": {"type": "object"}},
                        "faculty_development": {"type": "string"}
                    }
                },
                "student_life": {
                    "type": "object", 
                    "properties": {
                        "daily_schedule": {"type": "string"},
                        "house_system": {"type": "string"},
                        "student_support": {"type": "string"},
                        "counseling_services": {"type": "string"},
                        "special_needs_support": {"type": "string"},
                        "boarding_information": {"type": "string"}
                    }
                }
            }
        }
    
    def get_crawl_options(self, website_url: str) -> Dict[str, Any]:
        """Generate crawl configuration for a school website"""
        from urllib.parse import urlparse
        
        domain = urlparse(website_url).netloc
        
        return {
            'limit': 50,  # Max pages per school (most schools <20 pages)
            'maxDiscoveryDepth': 3,  # Don't go too deep into site structure
            'scrapeOptions': {
                'formats': [
                    'markdown',
                    {
                        'type': 'json',
                        'schema': self.school_schema
                    }
                ],
                'onlyMainContent': True,
                'maxAge': 86400000,  # 24-hour cache (1 day)
                'waitFor': 3000,  # Wait 3 seconds for dynamic content
                'removeBase64Images': True  # Reduce payload size
            },
            'allowedDomains': [domain],  # Stay on school website only
            'deduplicateSimilarURLs': True,  # Avoid duplicate content
            'excludePaths': [
                '/admin', '/wp-admin', '/login', '/signin', 
                '/register', '/signup', '/dashboard', '/private',
                '/staff-only', '/internal'
            ]  # Skip admin and private areas
        }
    
    def crawl_school_website(self, website_url: str, school_id: Optional[int] = None) -> Dict[str, Any]:
        """
        Crawl a single school website and extract structured data
        
        Returns:
        {
            'success': bool,
            'pages_found': int,
            'raw_data': List[Dict],  # All crawled pages
            'structured_data': Dict,  # Extracted structured information
            'error': Optional[str]
        }
        """
        try:
            logging.info(f"🔍 Starting crawl for {website_url}")
            
            # Start crawl job
            crawl_options = self.get_crawl_options(website_url)
            crawl_result = self.firecrawl.crawl_url(
                url=website_url,
                params=crawl_options
            )
            
            if not crawl_result.get('success'):
                error_msg = crawl_result.get('error', 'Unknown crawl error')
                logging.error(f"❌ Crawl failed for {website_url}: {error_msg}")
                return {
                    'success': False,
                    'pages_found': 0,
                    'raw_data': [],
                    'structured_data': {},
                    'error': error_msg
                }
            
            # Extract data from crawl results
            raw_pages = crawl_result.get('data', [])
            pages_found = len(raw_pages)
            
            logging.info(f"📄 Found {pages_found} pages for {website_url}")
            
            # Aggregate structured data from all pages
            structured_data = self.aggregate_structured_data(raw_pages)
            
            logging.info(f"✅ Successfully crawled {website_url} - {pages_found} pages")
            
            return {
                'success': True,
                'pages_found': pages_found,
                'raw_data': raw_pages,
                'structured_data': structured_data,
                'error': None
            }
            
        except Exception as e:
            error_msg = f"Exception during crawl: {str(e)}"
            logging.error(f"💥 {error_msg} for {website_url}")
            return {
                'success': False,
                'pages_found': 0,
                'raw_data': [],
                'structured_data': {},
                'error': error_msg
            }
    
    def aggregate_structured_data(self, raw_pages: List[Dict]) -> Dict[str, Any]:
        """
        Aggregate and merge structured data from all crawled pages
        """
        aggregated = {
            'basic_info': {},
            'academics': {},
            'admissions': {},
            'extracurricular': {},
            'facilities': {},
            'fees_costs': {},
            'contact_transport': {},
            'faculty_staff': {},
            'student_life': {}
        }
        
        for page in raw_pages:
            # Check if page has structured JSON data
            if 'json' in page and isinstance(page['json'], dict):
                json_data = page['json']
                
                # Merge each section, preferring non-empty values
                for section_key in aggregated.keys():
                    if section_key in json_data and json_data[section_key]:
                        section_data = json_data[section_key]
                        
                        if isinstance(section_data, dict):
                            # Merge dictionary data, keeping non-empty values
                            for field_key, field_value in section_data.items():
                                if field_value and field_key not in aggregated[section_key]:
                                    aggregated[section_key][field_key] = field_value
                                elif isinstance(field_value, list) and field_value:
                                    # Extend arrays, avoiding duplicates
                                    existing = aggregated[section_key].get(field_key, [])
                                    if isinstance(existing, list):
                                        combined = list(set(existing + field_value))
                                        aggregated[section_key][field_key] = combined
                                    else:
                                        aggregated[section_key][field_key] = field_value
        
        # Add metadata about the crawl
        aggregated['_metadata'] = {
            'pages_processed': len(raw_pages),
            'crawled_at': datetime.now().isoformat(),
            'pages_with_structured_data': len([p for p in raw_pages if 'json' in p])
        }
        
        return aggregated
    
    def update_database_record(self, school_id: int, crawl_result: Dict[str, Any]) -> bool:
        """Update Rails database with crawl results via API call"""
        try:
            # This would be called from the Rails rake task, not directly
            # The Python script returns results to Ruby for database updates
            logging.info(f"📝 Crawl result ready for school ID {school_id}")
            return True
            
        except Exception as e:
            logging.error(f"💾 Database update failed for school {school_id}: {e}")
            return False
    
    def print_summary(self):
        """Print crawling session summary"""
        elapsed = datetime.now() - self.stats['start_time']
        
        print("\n" + "🎉" * 20)
        print("CRAWLING SESSION COMPLETE!")
        print("🎉" * 20)
        print(f"📊 Final Statistics:")
        print(f"   Total processed: {self.stats['processed']}")
        print(f"   ✅ Successful: {self.stats['successful']}")
        print(f"   ❌ Failed: {self.stats['failed']}")
        print(f"   ⏱️  Total time: {elapsed}")
        
        if self.stats['processed'] > 0:
            success_rate = (self.stats['successful'] / self.stats['processed'] * 100)
            print(f"   📈 Success rate: {success_rate:.1f}%")


def main():
    """Main entry point for the script"""
    parser = argparse.ArgumentParser(description='Crawl school websites with Firecrawl')
    parser.add_argument('--school-id', type=int, help='Specific school ID to crawl')
    parser.add_argument('--website', type=str, help='Specific website URL to crawl')
    parser.add_argument('--all', action='store_true', help='Process all schools')
    parser.add_argument('--test', action='store_true', help='Test mode with single URL')
    
    args = parser.parse_args()
    
    # Get API key from environment
    api_key = os.getenv('FIRECRAWL_API_KEY')
    if not api_key:
        print("❌ FIRECRAWL_API_KEY environment variable not set")
        sys.exit(1)
    
    # Initialize crawler
    crawler = SchoolWebsiteCrawler(api_key)
    
    # Create logs directory if it doesn't exist
    os.makedirs('logs', exist_ok=True)
    
    try:
        if args.test:
            # Test with a known school website
            test_url = "https://www.bis.ac.th"  # Bangkok International School
            print(f"🧪 Testing with {test_url}")
            
            result = crawler.crawl_school_website(test_url)
            print(f"✅ Test result: {json.dumps(result, indent=2)}")
            
        elif args.website:
            # Crawl specific website
            result = crawler.crawl_school_website(args.website)
            print(json.dumps(result, indent=2, ensure_ascii=False))
            
        elif args.school_id:
            # This would get the website from the Rails database
            print(f"🔍 Would crawl school ID {args.school_id}")
            print("💡 This mode requires Rails integration - use rake task instead")
            
        elif args.all:
            # This would process all schools
            print("🌍 Would crawl all school websites")
            print("💡 This mode requires Rails integration - use rake task instead")
            
        else:
            print("❌ Please specify --school-id, --website, --all, or --test")
            parser.print_help()
    
    except KeyboardInterrupt:
        print("\n⛔ Crawling interrupted by user")
    except Exception as e:
        print(f"💥 Unexpected error: {e}")
    finally:
        crawler.print_summary()


if __name__ == "__main__":
    main()