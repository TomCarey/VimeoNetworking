//
//  MasterViewController.swift
//  VimeoNetworkingExample-iOS
//
//  Created by Huebner, Rob on 3/17/16.
//  Copyright © 2016 Vimeo. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import UIKit

class MasterViewController: UITableViewController
{
    var detailViewController: DetailViewController? = nil
    var videos: [VIMVideo] = []
    {
        didSet
        {
            self.tableView.reloadData()
        }
    }
    
    fileprivate var accountObservationToken: ObservationToken?
    fileprivate var authenticationButton: UIBarButtonItem?
    
    // MARK: - View Controller

    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        if let split = self.splitViewController
        {
            let controllers = split.viewControllers
            self.detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? DetailViewController
        }
        
        self.setupAccountObservation()
        
        self.authenticationButton = UIBarButtonItem(title: nil, style: .plain, target: self, action: #selector(didTapAuthenticationButton))
        self.updateAuthenticationButton()
        self.navigationItem.rightBarButtonItem = self.authenticationButton
    }

    override func viewWillAppear(_ animated: Bool)
    {
        self.clearsSelectionOnViewWillAppear = self.splitViewController?.isCollapsed ?? true

        super.viewWillAppear(animated)
    }
    
    // MARK: - Setup
    
    fileprivate func setupAccountObservation()
    {
        // This allows us to fetch a new list of items whenever the current account changes (on log in or log out events)
        
        self.accountObservationToken = Notification.AuthenticatedAccountDidChange.observe { [weak self] notification in
            
            guard let strongSelf = self
            else
            {
                return
            }
            
            let request: Request<[VIMVideo]>
            if VimeoClient.defaultClient.currentAccount?.isAuthenticatedWithUser() == true
            {
                request = Request<[VIMVideo]>(path: "/me/videos")
            }
            else
            {
                request = Request<[VIMVideo]>(path: "/channels/staffpicks/videos")
            }
            
            let _ = VimeoClient.defaultClient.request(request) { [weak self] result in
                
                guard let strongSelf = self
                else
                {
                    return
                }
                
                switch result
                {
                case .success(let response):
                    
                    strongSelf.videos = response.model
                    
                    if let nextPageRequest = response.nextPageRequest
                    {
                        print("starting next page request")
                        
                        let _ = VimeoClient.defaultClient.request(nextPageRequest) { [weak self] result in
                            
                            guard let strongSelf = self
                            else
                            {
                                return
                            }
                            
                            if case .success(let response) = result
                            {
                                print("next page request completed!")
                                strongSelf.videos.append(contentsOf: response.model)
                                strongSelf.tableView.reloadData()
                            }
                        }
                    }
                case .failure(let error):
                    let title = "Video Request Failed"
                    let message = "\(request.path) could not be loaded: \(error.localizedDescription)"
                    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                    let action = UIAlertAction(title: "OK", style: .default, handler: nil)
                    alert.addAction(action)
                    strongSelf.present(alert, animated: true, completion: nil)
                }
            }
            
            strongSelf.navigationItem.title = request.path
            strongSelf.updateAuthenticationButton()
        }
    }
    
    fileprivate func updateAuthenticationButton()
    {
        if VimeoClient.defaultClient.currentAccount?.isAuthenticatedWithUser() == true
        {
            self.authenticationButton?.title = "Log Out"
        }
        else
        {
            self.authenticationButton?.title = "Log In"
        }
    }
    
    // MARK: - Actions
    
    @objc fileprivate func didTapAuthenticationButton()
    {
        // If the user is logged in, the button logs them out.
        // If the user is logged out, the button launches the code grant authorization page.
        
        
        let authenticationController = AuthenticationController(client: VimeoClient.defaultClient)

        if VimeoClient.defaultClient.currentAccount?.isAuthenticatedWithUser() == true
        {
            do
            {
                try authenticationController.logOut()
            }
            catch let error as NSError
            {
                let title = "Couldn't Log Out"
                let message = "Logging out failed: \(error.localizedDescription)"
                let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                let action = UIAlertAction(title: "OK", style: .default, handler: nil)
                alert.addAction(action)
                self.present(alert, animated: true, completion: nil)
            }
        }
        else
        {
            authenticationController.accessToken("bd78fd35b66f732fbc1e176d5ff6826c", completion: { (result) in
                switch result
                {
                case .success(let account):
                    print("authenticated successfully: \(account)")
                    
                case .failure(let error):
                    print("failure authenticating: \(error)")
                }
            })
//            let URL = authenticationController.codeGrantAuthorizationURL()
            
//            UIApplication.shared.openURL(URL)
        }
    }

    // MARK: - Segues

    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        if segue.identifier == "showDetail"
        {
            if let indexPath = self.tableView.indexPathForSelectedRow
            {
                let object = videos[indexPath.row]
                let controller = (segue.destination as! UINavigationController).topViewController as! DetailViewController
                controller.detailItem = object
                controller.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem
                controller.navigationItem.leftItemsSupplementBackButton = true
            }
        }
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int
    {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return self.videos.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)

        let video = self.videos[indexPath.row]
        
        cell.textLabel!.text = video.name
        
        return cell
    }
}

